from fastapi.testclient import TestClient
from main import app
import os

client = TestClient(app)


def test_register_login_and_transfer():
    # register a user
    r = client.post('/register', data={'username':'testagent','password':'secret','role':'agent'})
    assert r.status_code in (200,400)

    # login
    r = client.post('/token', data={'username':'testagent','password':'secret'})
    assert r.status_code == 200
    token = r.json()['access_token']
    headers = {'Authorization': f'Bearer {token}'}

    # upload a small dummy file
    file_path = os.path.join(os.path.dirname(__file__), 'dummy.txt')
    with open(file_path, 'wb') as f:
        f.write(b'dummy')

    with open(file_path, 'rb') as f:
        r = client.post('/transfers', headers=headers, data={
            'agentName':'testagent',
            'senderNumber':'111',
            'receiverNumber':'222',
            'amount':'100',
            'charge':'15',
            'agentFee':'4.5'
        }, files={'file':('dummy.txt', f, 'text/plain')})
    assert r.status_code == 200
    j = r.json()
    assert 'id' in j
