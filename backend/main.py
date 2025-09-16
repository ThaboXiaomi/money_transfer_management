import os
import sqlite3
from datetime import datetime, timedelta
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends, Response
from fastapi.responses import FileResponse
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

SECRET_KEY = 'change-me-to-a-secure-random-string'
ALGORITHM = 'HS256'
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
oauth2_scheme = OAuth2PasswordBearer(tokenUrl='token')

app = FastAPI(title='Money Transfer Backend')
app.mount('/uploads', StaticFiles(directory=UPLOAD_DIR), name='uploads')

# Optional static assets (serve a favicon)
STATIC_DIR = os.path.join(BASE_DIR, 'static')
os.makedirs(STATIC_DIR, exist_ok=True)

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
app.add_middleware(
    CORSMiddleware,
    # Allow common development origins (localhost, 127.0.0.1, Android emulator 10.0.2.2)
    allow_origins=[],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$",
    # You can switch to allow_origins=['https://yourdomain.com'] in prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware('http')
async def log_requests(request, call_next):
    # Simple request logger to help debugging connectivity/CORS issues
    try:
        print(f"[REQ] {request.method} {request.url}")
    except Exception:
        pass
    response = await call_next(request)
    try:
        print(f"[RESP] {request.method} {request.url} -> {response.status_code}")
    except Exception:
        pass
    return response


@app.get('/ping')
def ping(origin: Optional[str] = None):
    # convenience endpoint for frontend to verify connectivity
    return {'ok': True, 'time': datetime.utcnow().isoformat(), 'note': 'pong'}


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


@app.on_event('startup')
def startup():
    init_db()


@app.post('/token', response_model=Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=401, detail='Incorrect username or password')
    access_token = create_access_token({'sub': user['username']}, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    return {'access_token': access_token, 'token_type': 'bearer'}


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
    agentName: str = Form(...),
    senderNumber: str = Form(...),
    receiverNumber: str = Form(...),
    amount: float = Form(...),
    charge: float = Form(...),
    agentFee: float = Form(...),
    destination: Optional[str] = Form(''),
    txRef: Optional[str] = Form(''),
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
):
    # save file
    filename = f"{int(__import__('time').time())}_{file.filename}"
    dest = os.path.join(UPLOAD_DIR, filename)
    with open(dest, 'wb') as f:
        f.write(await file.read())

    conn = get_conn()
    cur = conn.cursor()
    now = datetime.utcnow().isoformat()
    cur.execute(
        'INSERT INTO transfers (agentName,senderNumber,receiverNumber,amount,charge,agentFee,screenshotPath,status,destination,txRef,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        (agentName, senderNumber, receiverNumber, amount, charge, agentFee, filename, 'pending', destination, txRef, now),
    )
    conn.commit()
    id_ = cur.lastrowid
    conn.close()
    return {'id': id_, 'screenshotUrl': f'/uploads/{filename}'}


@app.get('/transfers')
def list_transfers(current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM transfers ORDER BY id DESC')
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.get('/recipients')
def list_recipients(current_user=Depends(get_current_user)):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute('SELECT * FROM recipients ORDER BY id DESC')
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
def export_csv(current_user=Depends(get_current_user)):
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
    return Response(iter_csv(), media_type='text/csv')

