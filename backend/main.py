import os
import sqlite3
import time
import uuid
import hashlib
import json
from collections import defaultdict
from datetime import datetime, timedelta
from threading import Lock
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends, Response, Body, Request
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
import csv

# --- config ---
BASE_DIR = os.path.dirname(__file__)
UPLOAD_DIR = os.path.join(BASE_DIR, 'uploads')
os.makedirs(UPLOAD_DIR, exist_ok=True)
DB_PATH = os.path.join(BASE_DIR, 'transfers.db')

SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-insecure-change-me')
ALGORITHM = 'HS256'
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
LOGIN_MAX_ATTEMPTS = int(os.environ.get('LOGIN_MAX_ATTEMPTS', '5'))
LOGIN_WINDOW_SECONDS = int(os.environ.get('LOGIN_WINDOW_SECONDS', '900'))
IDEMPOTENCY_TTL_SECONDS = int(os.environ.get('IDEMPOTENCY_TTL_SECONDS', '1800'))

failed_logins = defaultdict(list)
idempotency_cache = {}
security_lock = Lock()

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
oauth2_scheme = OAuth2PasswordBearer(tokenUrl='/token')
# Optional scheme for endpoints that may be accessed anonymously in dev
oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl='/token', auto_error=False)

app = FastAPI(title='Money Transfer Backend')
app.mount('/uploads', StaticFiles(directory=UPLOAD_DIR), name='uploads')

# Optional static assets (serve a favicon)
STATIC_DIR = os.path.join(BASE_DIR, 'static')
os.makedirs(STATIC_DIR, exist_ok=True)

# Serve the Flutter web assets (if the web build or dev server files are
# placed alongside the backend). This makes requests like
# GET /assets/backend_override.txt return the file instead of hitting
# application routes.
ASSETS_DIR = os.path.normpath(os.path.join(BASE_DIR, '..', 'assets'))
if os.path.exists(ASSETS_DIR):
    try:
        # Mount the assets directory at /assets. Avoid mounting a nested
        # '/assets/assets' path because that can cause ambiguous routing where
        # requests end up hitting application routes unexpectedly (seen in dev
        # mode as "Bad state: No element"). If a caller requests
        # '/assets/assets/...' it's usually a client-side path bug and should
        # be adjusted there instead of adding another mount.
        app.mount('/assets', StaticFiles(directory=ASSETS_DIR), name='assets')
    except Exception:
        # If mounting fails for any reason, continue without asset mount.
        pass

@app.get('/')
def root():
    return {'status': 'ok'}


@app.get('/favicon.ico')
def favicon():
    # Try serving the app logo from the Flutter assets folder as favicon.
    logo_path = os.path.join(BASE_DIR, '..', 'assets', 'logo.jpg')
    logo_path = os.path.normpath(logo_path)
    if os.path.exists(logo_path):
        return FileResponse(logo_path, media_type='image/jpeg')
    # fallback to static/favicon.ico if present
    fav_path = os.path.join(STATIC_DIR, 'favicon.ico')
    if os.path.exists(fav_path):
        return FileResponse(fav_path, media_type='image/x-icon')
    raise HTTPException(status_code=404, detail='favicon not found')

# CORS - allow requests from local dev servers / Flutter web during development
# CORS - allow requests from local dev servers / Flutter web during development
# When running in a browser, Access-Control-Allow-Credentials cannot be set to
# true together with a wildcard origin. The app uses bearer tokens in
# Authorization headers (not cookies), so credentials are not required.
# allow_credentials=False avoids CORS rejections in web builds. In production
# set CORS_ORIGINS to a comma-separated list of allowed origins and consider
# enabling allow_credentials if you use cookies.
cors_env = os.environ.get('CORS_ORIGINS')
if cors_env:
    allow_origins = [o.strip() for o in cors_env.split(',') if o.strip()]
else:
    allow_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Authorization", "access_token", "content-type"],
    max_age=600,
)


@app.middleware('http')
async def log_requests(request, call_next):
    # Simple request logger to help debugging connectivity/CORS issues
    try:
        print(f"[REQ] {request.method} {request.url}")
    except Exception:
        pass
    response = await call_next(request)
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Cache-Control'] = 'no-store'
    try:
        print(f"[RESP] {request.method} {request.url} -> {response.status_code}")
    except Exception:
        pass
    return response


@app.get('/ping')
def ping(origin: Optional[str] = None):
    # convenience endpoint for frontend to verify connectivity
    return {'ok': True, 'time': datetime.utcnow().isoformat(), 'note': 'pong'}


def _prune_old_attempts(now_ts: float):
    cutoff = now_ts - LOGIN_WINDOW_SECONDS
    with security_lock:
        for username in list(failed_logins.keys()):
            recent = [ts for ts in failed_logins[username] if ts >= cutoff]
            if recent:
                failed_logins[username] = recent
            else:
                failed_logins.pop(username, None)


def _check_login_rate_limit(username: str):
    now_ts = time.time()
    _prune_old_attempts(now_ts)
    attempts = failed_logins.get(username, [])
    if len(attempts) >= LOGIN_MAX_ATTEMPTS:
        raise HTTPException(status_code=429, detail='Too many failed login attempts. Please try again later.')


def _record_failed_login(username: str):
    with security_lock:
        failed_logins[username].append(time.time())


def _clear_failed_logins(username: str):
    with security_lock:
        failed_logins.pop(username, None)


def _prune_idempotency_cache(now_ts: float):
    cutoff = now_ts - IDEMPOTENCY_TTL_SECONDS
    with security_lock:
        for key in list(idempotency_cache.keys()):
            if idempotency_cache[key].get('created', 0) < cutoff:
                idempotency_cache.pop(key, None)


def _idempotency_scope_key(username: str, idem_key: str) -> str:
    return f'{username}:{idem_key}'


def _build_transfer_payload_hash(
    agent_name: str,
    sender_number: str,
    receiver_number: str,
    amount: float,
    charge: float,
    agent_fee: float,
    destination_value: str,
    tx_ref: str,
) -> str:
    payload = {
        'agentName': agent_name,
        'senderNumber': sender_number,
        'receiverNumber': receiver_number,
        'amount': amount,
        'charge': charge,
        'agentFee': agent_fee,
        'destination': destination_value,
        'txRef': tx_ref,
    }
    encoded = json.dumps(payload, sort_keys=True, separators=(',', ':')).encode('utf-8')
    return hashlib.sha256(encoded).hexdigest()


def _transfer_response_payload(row: sqlite3.Row) -> dict:
    screenshot_path = row['screenshotPath'] if row['screenshotPath'] else ''
    screenshot_url = f"/uploads/{screenshot_path}" if screenshot_path else None
    return {'id': row['id'], 'publicId': row['publicId'], 'screenshotUrl': screenshot_url}


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_conn()
    conn.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        hashed_password TEXT,
        role TEXT
    )
    ''')
    conn.execute('''
    CREATE TABLE IF NOT EXISTS transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        publicId TEXT UNIQUE,
        idempotencyKey TEXT,
        agentName TEXT,
        senderNumber TEXT,
        receiverNumber TEXT,
        amount REAL,
        charge REAL,
        agentFee REAL,
        screenshotPath TEXT,
        status TEXT,
        destination TEXT,
        txRef TEXT,
        created_at TEXT
    )
    ''')
    # lightweight migrations for existing DB files
    cols = {r['name'] for r in conn.execute("PRAGMA table_info(transfers)").fetchall()}
    if 'publicId' not in cols:
        conn.execute('ALTER TABLE transfers ADD COLUMN publicId TEXT')
    if 'idempotencyKey' not in cols:
        conn.execute('ALTER TABLE transfers ADD COLUMN idempotencyKey TEXT')
    conn.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_transfers_public_id ON transfers(publicId)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_transfers_idempotency ON transfers(idempotencyKey)')
    conn.execute('''
    CREATE TABLE IF NOT EXISTS recipients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ownerId TEXT,
        name TEXT,
        phone TEXT,
        country TEXT,
        bankName TEXT,
        bankAccount TEXT,
        iban TEXT,
        address TEXT
    )
    ''')
    # ensure there is an admin user (default password: admin)
    cur = conn.cursor()
    cur.execute("SELECT id FROM users WHERE username = ?", ('admin',))
    if cur.fetchone() is None:
        hashed = pwd_context.hash('admin')
        cur.execute('INSERT INTO users (username, hashed_password, role) VALUES (?,?,?)', ('admin', hashed, 'admin'))
    conn.commit()
    conn.close()


class Token(BaseModel):
    access_token: str
    token_type: str


def authenticate_user(username: str, password: str):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM users WHERE username = ?', (username,))
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    if not pwd_context.verify(password, row['hashed_password']):
        return None
    return {'id': row['id'], 'username': row['username'], 'role': row['role']}


def password_strength(password: str) -> float:
    score = 0.0
    if len(password) >= 6:
        score += 0.3
    if len(password) >= 10:
        score += 0.2
    if any(c.isupper() for c in password):
        score += 0.15
    if any(c.isdigit() for c in password):
        score += 0.2
    if any(not c.isalnum() for c in password):
        score += 0.15
    return min(score, 1.0)


def _has_upper_and_digit(password: str) -> bool:
    return any(c.isupper() for c in password) and any(c.isdigit() for c in password)


@app.post('/password_strength')
def check_password_strength(password: str = Form(...)):
    s = password_strength(password)
    return {'strength': s, 'score': s, 'hasUpperAndDigit': _has_upper_and_digit(password)}


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({'exp': expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get('sub')
        if username is None:
            raise HTTPException(status_code=401, detail='Invalid token')
    except JWTError:
        raise HTTPException(status_code=401, detail='Invalid token')
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM users WHERE username = ?', (username,))
    row = cur.fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=401, detail='User not found')
    return {'id': row['id'], 'username': row['username'], 'role': row['role']}


async def get_optional_current_user(token: Optional[str] = Depends(oauth2_scheme_optional)):
    # Return user dict when a valid token is supplied; otherwise return None
    if not token:
        return None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get('sub')
        if username is None:
            return None
    except JWTError:
        return None
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM users WHERE username = ?', (username,))
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {'id': row['id'], 'username': row['username'], 'role': row['role']}


@app.on_event('startup')
def startup():
    init_db()


@app.post('/token', response_model=Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    username = form_data.username.strip()
    _check_login_rate_limit(username)
    user = authenticate_user(username, form_data.password)
    if not user:
        _record_failed_login(username)
        raise HTTPException(status_code=401, detail='Incorrect username or password')
    _clear_failed_logins(username)
    access_token = create_access_token({'sub': user['username']}, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    return {'access_token': access_token, 'token_type': 'bearer'}


@app.post('/logout')
def logout(current_user=Depends(get_optional_current_user)):
    # No-op endpoint: placeholder for client-initiated logout/revocation.
    try:
        user = current_user['username'] if current_user else 'anonymous'
        print(f"[LOGOUT] requested by {user}")
    except Exception:
        pass
    return {'ok': True}


@app.post('/register')
def register(username: str = Form(...), password: str = Form(...), role: str = Form('agent')):
    # Validate password length and strength
    try:
        min_strength = float(os.environ.get('PASSWORD_MIN_STRENGTH', '0.6'))
    except Exception:
        min_strength = 0.6
    if not password or len(password) < 6:
        raise HTTPException(status_code=400, detail='Password must be at least 6 characters')
    # enforce stronger policy: require at least one uppercase and one digit
    if not _has_upper_and_digit(password):
        raise HTTPException(status_code=400, detail='Password must include at least one uppercase letter and one digit')
    strength = password_strength(password)
    if strength < min_strength:
        raise HTTPException(status_code=400, detail=f'Password too weak (strength {strength:.2f}), required >= {min_strength}')

    conn = get_conn()
    cur = conn.cursor()
    hashed = pwd_context.hash(password)
    try:
        cur.execute('INSERT INTO users (username, hashed_password, role) VALUES (?,?,?)', (username, hashed, role))
        conn.commit()
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=400, detail='Username already exists')
    conn.close()
    return {'username': username, 'role': role}


@app.post('/transfers')
async def create_transfer(
    request: Request,
    agentName: str = Form(...),
    senderNumber: str = Form(...),
    receiverNumber: str = Form(...),
    amount: float = Form(...),
    charge: float = Form(...),
    agentFee: float = Form(...),
    destination: Optional[str] = Form(''),
    txRef: Optional[str] = Form(''),
    file: Optional[UploadFile] = File(None),
    current_user=Depends(get_current_user),
):
    # basic validation to keep transfer records consistent
    if amount <= 0:
        raise HTTPException(status_code=400, detail='Amount must be greater than zero')
    if charge < 0 or agentFee < 0:
        raise HTTPException(status_code=400, detail='Charge and agent fee cannot be negative')
    agent_name = agentName.strip()
    sender_number = senderNumber.strip()
    receiver_number = receiverNumber.strip()
    destination_value = (destination or '').strip()
    tx_ref = (txRef or '').strip()

    if not agent_name or not sender_number or not receiver_number:
        raise HTTPException(status_code=400, detail='Agent, sender and receiver fields are required')

    idem_key = ''
    if request is not None:
        idem_key = (request.headers.get('Idempotency-Key') or '').strip()

    payload_hash = _build_transfer_payload_hash(
        agent_name,
        sender_number,
        receiver_number,
        amount,
        charge,
        agentFee,
        destination_value,
        tx_ref,
    )

    filename = ''
    # save file when provided
    if file is not None and file.filename:
        original_name = os.path.basename(file.filename).replace(' ', '_')
        filename = f"{int(time.time())}_{uuid.uuid4().hex[:8]}_{original_name}"
        dest = os.path.join(UPLOAD_DIR, filename)
        with open(dest, 'wb') as f:
            f.write(await file.read())

    conn = get_conn()
    try:
        cur = conn.cursor()
        now_ts = time.time()
        _prune_idempotency_cache(now_ts)

        if idem_key:
            cache_key = _idempotency_scope_key(current_user['username'], idem_key)
            with security_lock:
                cached = idempotency_cache.get(cache_key)
                if cached:
                    if cached.get('payloadHash') != payload_hash:
                        raise HTTPException(status_code=409, detail='Idempotency-Key reused with different transfer payload')
                    return cached['response']

                cur.execute(
                    'SELECT * FROM transfers WHERE idempotencyKey = ? AND agentName = ? ORDER BY id DESC LIMIT 1',
                    (idem_key, current_user['username']),
                )
                existing = cur.fetchone()
                if existing:
                    existing_hash = _build_transfer_payload_hash(
                        existing['agentName'] or '',
                        existing['senderNumber'] or '',
                        existing['receiverNumber'] or '',
                        float(existing['amount'] or 0),
                        float(existing['charge'] or 0),
                        float(existing['agentFee'] or 0),
                        existing['destination'] or '',
                        existing['txRef'] or '',
                    )
                    if existing_hash != payload_hash:
                        raise HTTPException(status_code=409, detail='Idempotency-Key reused with different transfer payload')
                    payload = _transfer_response_payload(existing)
                    idempotency_cache[cache_key] = {
                        'created': now_ts,
                        'payloadHash': payload_hash,
                        'response': payload,
                    }
                    return payload

                now = datetime.utcnow().isoformat()
                public_id = f"tr_{datetime.utcnow().strftime('%Y%m%d')}_{uuid.uuid4().hex[:12]}"
                cur.execute(
                    'INSERT INTO transfers (publicId,idempotencyKey,agentName,senderNumber,receiverNumber,amount,charge,agentFee,screenshotPath,status,destination,txRef,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
                    (public_id, idem_key, agent_name, sender_number, receiver_number, amount, charge, agentFee, filename, 'pending', destination_value, tx_ref, now),
                )
                conn.commit()
                payload = {'id': cur.lastrowid, 'publicId': public_id, 'screenshotUrl': f'/uploads/{filename}' if filename else None}
                idempotency_cache[cache_key] = {
                    'created': now_ts,
                    'payloadHash': payload_hash,
                    'response': payload,
                }
                return payload

        now = datetime.utcnow().isoformat()
        public_id = f"tr_{datetime.utcnow().strftime('%Y%m%d')}_{uuid.uuid4().hex[:12]}"
        cur.execute(
            'INSERT INTO transfers (publicId,idempotencyKey,agentName,senderNumber,receiverNumber,amount,charge,agentFee,screenshotPath,status,destination,txRef,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
            (public_id, '', agent_name, sender_number, receiver_number, amount, charge, agentFee, filename, 'pending', destination_value, tx_ref, now),
        )
        conn.commit()
        return {'id': cur.lastrowid, 'publicId': public_id, 'screenshotUrl': f'/uploads/{filename}' if filename else None}
    finally:
        conn.close()


@app.get('/transfers')
def list_transfers(current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM transfers ORDER BY id DESC')
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.delete('/transfers/{transfer_id}')
def delete_transfer(transfer_id: int, current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT screenshotPath FROM transfers WHERE id = ?', (transfer_id,))
    row = cur.fetchone()
    if row is None:
        conn.close()
        raise HTTPException(status_code=404, detail='Transfer not found')
    filename = row['screenshotPath'] if row['screenshotPath'] is not None else ''
    cur.execute('DELETE FROM transfers WHERE id = ?', (transfer_id,))
    conn.commit()
    conn.close()
    # attempt to remove uploaded file if present
    try:
        if filename:
            fp = os.path.join(UPLOAD_DIR, filename)
            if os.path.exists(fp):
                os.remove(fp)
    except Exception:
        pass
    return {'ok': True}


@app.put('/transfers/{transfer_id}')
def update_transfer(transfer_id: int, payload: dict = Body(...), current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM transfers WHERE id = ?', (transfer_id,))
    if cur.fetchone() is None:
        conn.close()
        raise HTTPException(status_code=404, detail='Transfer not found')

    allowed = ['agentName', 'senderNumber', 'receiverNumber', 'amount', 'charge', 'agentFee', 'screenshotPath', 'status', 'destination', 'txRef']
    sets = []
    vals = []
    for k in allowed:
        if k in payload:
            val = payload[k]
            if k in ('amount', 'charge', 'agentFee'):
                try:
                    val = float(val)
                except Exception:
                    # leave as-is; sqlite will coerce or fail
                    pass
            sets.append(f"{k} = ?")
            vals.append(val)
    if sets:
        vals.append(transfer_id)
        sql = 'UPDATE transfers SET ' + ','.join(sets) + ' WHERE id = ?'
        cur.execute(sql, tuple(vals))
        conn.commit()
    conn.close()
    return {'ok': True}


@app.get('/recipients')
def list_recipients(current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM recipients ORDER BY id DESC')
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.get('/users')
def list_users(current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT id, username, role FROM users ORDER BY id DESC')
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.post('/recipients')
def create_recipient(
    ownerId: str = Form(...),
    name: str = Form(...),
    phone: str = Form(...),
    country: str = Form(...),
    bankName: Optional[str] = Form(None),
    bankAccount: Optional[str] = Form(None),
    iban: Optional[str] = Form(None),
    address: Optional[str] = Form(None),
    current_user=Depends(get_current_user),
):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        'INSERT INTO recipients (ownerId,name,phone,country,bankName,bankAccount,iban,address) VALUES (?,?,?,?,?,?,?,?)',
        (ownerId, name, phone, country, bankName or '', bankAccount or '', iban or '', address or ''),
    )
    conn.commit()
    id_ = cur.lastrowid
    conn.close()
    return {'id': id_}


@app.get('/dashboard')
def dashboard_summary(current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) as total FROM transfers")
    total = cur.fetchone()['total']
    cur.execute("SELECT COUNT(*) as pending FROM transfers WHERE status = 'pending'")
    pending = cur.fetchone()['pending']
    cur.execute("SELECT COUNT(*) as completed FROM transfers WHERE status = 'sent'")
    completed = cur.fetchone()['completed']
    cur.execute("SELECT COALESCE(SUM(amount),0) as total_volume FROM transfers")
    total_volume = cur.fetchone()['total_volume']
    cur.execute("SELECT COALESCE(SUM(charge),0) as total_fees FROM transfers")
    total_fees = cur.fetchone()['total_fees']
    conn.close()
    return {
        'totalTransfers': total,
        'pending': pending,
        'completed': completed,
        'totalVolume': total_volume,
        'totalFees': total_fees,
        'since': datetime.utcnow().isoformat(),
    }


@app.post('/transfers/{transfer_id}/mark_sent')
def mark_sent(transfer_id: int, txRef: str = Form(...), current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM transfers WHERE id = ?', (transfer_id,))
    if cur.fetchone() is None:
        conn.close()
        raise HTTPException(status_code=404, detail='Transfer not found')
    cur.execute('UPDATE transfers SET status = ?, txRef = ? WHERE id = ?', ('sent', txRef, transfer_id))
    conn.commit()
    conn.close()
    return {'ok': True}


@app.get('/transfers/export/csv')
def export_csv(current_user=Depends(get_optional_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM transfers ORDER BY id DESC')
    rows = cur.fetchall()
    conn.close()
    def iter_csv():
        header = ['id','agentName','senderNumber','receiverNumber','amount','charge','agentFee','screenshotPath','status','destination','txRef','created_at']
        yield ','.join(header) + '\n'
        for r in rows:
            row = [str(r[h]) if r[h] is not None else '' for h in header]
            yield ','.join(row) + '\n'
    return StreamingResponse(iter_csv(), media_type='text/csv')
