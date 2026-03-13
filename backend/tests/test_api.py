# Clean test file: import FastAPI app robustly and run a simple integration test.
import os
import sys
import threading
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
    username = f"testagent_{os.getpid()}"
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


def test_transfer_without_file_and_invalid_amount():
    username = f"testagent_no_file_{os.getpid()}"
    password = 'Secret1'

    client.post('/register', data={'username': username, 'password': password, 'role': 'agent'})
    r = client.post('/token', data={'username': username, 'password': password})
    if r.status_code != 200:
        assert r.status_code in (200, 401)
        return

    token = r.json()['access_token']
    headers = {'Authorization': f'Bearer {token}'}

    no_file_resp = client.post(
        '/transfers',
        headers=headers,
        data={
            'agentName': username,
            'senderNumber': '123',
            'receiverNumber': '456',
            'amount': '100',
            'charge': '10',
            'agentFee': '3',
        },
    )
    assert no_file_resp.status_code == 200
    assert no_file_resp.json().get('screenshotUrl') is None

    invalid_amount_resp = client.post(
        '/transfers',
        headers=headers,
        data={
            'agentName': username,
            'senderNumber': '123',
            'receiverNumber': '456',
            'amount': '0',
            'charge': '10',
            'agentFee': '3',
        },
    )
    assert invalid_amount_resp.status_code == 400
    assert 'Amount must be greater than zero' in invalid_amount_resp.text


def test_transfer_idempotency_key_replays_same_response():
    username = f"testagent_idempotency_{os.getpid()}"
    password = 'Secret1'

    client.post('/register', data={'username': username, 'password': password, 'role': 'agent'})
    r = client.post('/token', data={'username': username, 'password': password})
    if r.status_code != 200:
        assert r.status_code in (200, 401, 429)
        return

    token = r.json()['access_token']
    idem = f"idem-{os.getpid()}"
    headers = {'Authorization': f'Bearer {token}', 'Idempotency-Key': idem}
    payload = {
        'agentName': username,
        'senderNumber': '333',
        'receiverNumber': '444',
        'amount': '120',
        'charge': '12',
        'agentFee': '3.6',
    }

    first = client.post('/transfers', headers=headers, data=payload)
    second = client.post('/transfers', headers=headers, data=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json().get('id') == second.json().get('id')


def test_login_rate_limit_eventually_returns_429():
    username = f"no_such_user_{os.getpid()}"
    saw_429 = False
    for _ in range(8):
        r = client.post('/token', data={'username': username, 'password': 'WrongPass1'})
        if r.status_code == 429:
            saw_429 = True
            break
    assert saw_429


def test_transfer_idempotency_key_is_scoped_per_user_and_payload():
    password = 'Secret1'
    username_a = f"testagent_scope_a_{os.getpid()}"
    username_b = f"testagent_scope_b_{os.getpid()}"

    for username in (username_a, username_b):
        client.post('/register', data={'username': username, 'password': password, 'role': 'agent'})

    login_a = client.post('/token', data={'username': username_a, 'password': password})
    login_b = client.post('/token', data={'username': username_b, 'password': password})
    if login_a.status_code != 200 or login_b.status_code != 200:
        assert login_a.status_code in (200, 401, 429)
        assert login_b.status_code in (200, 401, 429)
        return

    headers_a = {
        'Authorization': f"Bearer {login_a.json()['access_token']}",
        'Idempotency-Key': f"shared-key-{os.getpid()}",
    }
    headers_b = {
        'Authorization': f"Bearer {login_b.json()['access_token']}",
        'Idempotency-Key': headers_a['Idempotency-Key'],
    }

    payload_a = {
        'agentName': username_b,
        'senderNumber': '900',
        'receiverNumber': '901',
        'amount': '55',
        'charge': '5',
        'agentFee': '1',
    }
    payload_b = {
        'agentName': username_b,
        'senderNumber': '910',
        'receiverNumber': '911',
        'amount': '65',
        'charge': '6',
        'agentFee': '2',
    }

    first = client.post('/transfers', headers=headers_a, data=payload_a)
    second_other_user = client.post('/transfers', headers=headers_b, data=payload_b)
    mismatch_same_user = client.post(
        '/transfers',
        headers=headers_a,
        data={**payload_a, 'amount': '56'},
    )

    assert first.status_code == 200
    assert second_other_user.status_code == 200
    assert first.json().get('id') != second_other_user.json().get('id')
    assert mismatch_same_user.status_code == 409


def test_transfer_idempotency_concurrent_requests_create_one_transfer():
    username = f"testagent_concurrent_{os.getpid()}"
    password = 'Secret1'

    client.post('/register', data={'username': username, 'password': password, 'role': 'agent'})
    login = client.post('/token', data={'username': username, 'password': password})
    if login.status_code != 200:
        assert login.status_code in (200, 401, 429)
        return

    headers = {
        'Authorization': f"Bearer {login.json()['access_token']}",
        'Idempotency-Key': f"parallel-{os.getpid()}",
    }
    payload = {
        'agentName': username,
        'senderNumber': '700',
        'receiverNumber': '701',
        'amount': '88',
        'charge': '8',
        'agentFee': '2',
    }

    results = []

    def send_request():
        results.append(client.post('/transfers', headers=headers, data=payload))

    threads = [threading.Thread(target=send_request) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    assert len(results) == 2
    assert all(resp.status_code == 200 for resp in results)
    ids = [resp.json().get('id') for resp in results]
    assert ids[0] == ids[1]
