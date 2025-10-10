# Deploying to Render

This project contains a FastAPI backend (in `backend/`) and a Flutter web frontend. The repository includes a `render.yaml` manifest and a Dockerfile to build and serve the Flutter web app.

Quick steps to deploy both services on Render:

1. Push this repo to GitHub (if not already).
2. Go to https://render.com and create a new account or sign in.
3. Import the repository and choose `Connect a repository`.
4. When Render requests which service to create from the repo, choose to import from the `render.yaml` manifest (Render will read `render.yaml` and create the two services automatically).

Backend (money-transfer-backend):
- Type: Web Service (Python)
- Working directory: `backend`
- Build command: `pip install -r requirements.txt` (already in `render.yaml`)
- Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

Important environment variables:
- SECRET_KEY — change from the default `change-me-to-a-secure-random-string` to a secure random value in Render's dashboard (Environment -> Environment Variables).

Frontend (money-transfer-frontend):
- Type: Web Service (Docker)
- Render will use `web.Dockerfile` to build and deploy the Flutter web app. The Dockerfile builds the web assets with Flutter and serves them with nginx.

Notes and troubleshooting:
- The backend uses SQLite for storage (file `backend/transfers.db`). On Render, the filesystem is ephemeral across deploys. For production use, migrate to a managed DB (Postgres) and update the backend to use it. For short-lived demos, you can persist files using an external storage service.
- To enable uploads to persist across deploys, configure an S3-compatible bucket and modify the backend to store files there instead of the local `uploads/` folder.
- If the frontend cannot reach the backend due to CORS or incorrect base URL, set the backend base URL in the Flutter app (or serve the frontend from the same domain via a custom domain and configure CORS accordingly).
- For faster Docker builds on Render, consider caching Flutter SDK or using a build container provided by Render (this manifest uses a multi-stage Dockerfile with `cirrusci/flutter` image as the builder).

That's it — after the services are created, push commits to trigger builds and deployments. If you want, I can also add an example `Procfile`, or help migrate the backend to Postgres and Wire up file storage.
