import os
import sqlite3
from datetime import datetime, timedelta
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends, Response
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

# CORS - allow requests from local dev servers / Flutter web during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # change to specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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

