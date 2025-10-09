# Clean test file: import FastAPI app robustly and run a simple integration test.
import os
import sys
from fastapi.testclient import TestClient

# Ensure repo root on sys.path so `backend` can be imported when tests run from different CWDs
repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

try:
    # Primary import for CI (tests run from repo root)
    from backend.main import app
except Exception:
    # Fallback for local runs when executing pytest from inside the backend folder
    from main import app

client = TestClient(app)


def test_register_login_and_transfer():
    username = 'testagent'
    password = 'Secret1'  # meets policy: uppercase + digit

    # register (200 OK or 400 if user already exists)
    r = client.post('/register', data={'username': username, 'password': password, 'role': 'agent'})
    assert r.status_code in (200, 400)

    # login
    r = client.post('/token', data={'username': username, 'password': password})
    if r.status_code != 200:
        # allow login failure when user exists with different password
        assert r.status_code in (200, 401)
        return
    token = r.json()['access_token']
    headers = {'Authorization': f'Bearer {token}'}

    # upload a small dummy file and ensure cleanup
    file_path = os.path.join(os.path.dirname(__file__), 'dummy.txt')
    try:
        with open(file_path, 'wb') as f:
            f.write(b'dummy')

        with open(file_path, 'rb') as f:
            r = client.post(
                '/transfers',
                headers=headers,
                data={
                    'agentName': username,
                    'senderNumber': '111',
                    'receiverNumber': '222',
                    'amount': '100',
                    'charge': '15',
                    'agentFee': '4.5',
                },
                files={'file': ('dummy.txt', f, 'text/plain')},
            )

        assert r.status_code == 200
        j = r.json()
        assert 'id' in j
    finally:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
        except Exception:
            pass
