# Money Transfer Backend

This is a minimal FastAPI backend used by the Flutter app for storing transfers and screenshots.

Setup (recommended in a Python virtualenv):

1. Create and activate a virtualenv (Windows PowerShell):

```powershell
python -m venv .venv; .\.venv\Scripts\Activate.ps1
```

2. Install requirements:

```powershell
pip install -r requirements.txt
```

3. Run the server (development):

```powershell
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Notes:
- Uploaded screenshots are saved to `backend/uploads/` and served at `/uploads/<filename>`.
- The DB is `backend/transfers.db` (SQLite).
- The Flutter emulator Android should use `AppConfig.backendBase = 'http://10.0.2.2:8000'` to reach your host machine. For iOS/macOS use `http://localhost:8000`.

Security and production:
- This backend is for prototyping. For production, add authentication, input validation, HTTPS, file size limits, and virus scanning of uploads.
