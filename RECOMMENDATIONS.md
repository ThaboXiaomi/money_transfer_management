Recommendations for money_transfer_management project

Overview
- Goal: small money transfer admin + client Flutter app with FastAPI backend.
- Focus on: reliability, data integrity, security, and maintainability.

Immediate recommendations

1) Persist Admin Settings
- Add SharedPreferences-backed load/save in `AppConfig` (lib/services/config_io.dart) so currency and other settings survive app restarts.
- Expose a small `AppConfig.load()` and `AppConfig.save()` called from app startup (e.g., in `main()` or `app_init`).

2) Create Agents and Recipients tables
- Add `agents` and `recipients` tables to LocalDb schema and expose CRUD helpers in `LocalDb`.
- This removes the current workaround of creating dummy transfers when adding agents.

3) Persist Notifications and Audit
- Add `notifications` and `audit` tables to LocalDb and write audit events on key actions (user create, mark transfer sent, delete operations).
- Optionally stream audit to backend for central logging.

4) User management and RBAC
- Implement roles in `users` (admin, agent, viewer) and enforce in the backend via JWT claims.
- Harden register/login flows to validate input and return clear error messages.

5) Currency and formatting
- Centralize currency formatting in `AppConfig.formatCurrency` which you've added; replace remaining hard-coded "R" strings across the app.
- Consider using the `intl` package for localization and currency formatting for production.

6) Backend improvements
- Add database migrations (alembic or simple migration script) to evolve SQLite schema safely.
- Harden CORS rules for production; for dev use allow_origin_regex but restrict in production.
- Add rate limiting and input sanitization on endpoints that accept user-provided CSVs or files.

7) Tests
- Add unit tests for backend endpoints and frontend service methods (`ApiService`).
- Add a small integration test that runs the backend TestClient and exercises create/login/upload flows.

8) CI/CD
- Add GitHub Actions to run `flutter analyze`, `flutter test`, `pytest` for backend, and a lint step.

9) UX
- Improve form validation on create transfer and registration screens; show inline validation errors.
- Add confirmations for destructive actions (deletes) and toast/success messages.

10) Security
- Store JWT securely on the client (secure storage on mobile), use https in production, and rotate secrets.

Medium-term projects
- Implement exchange rate provider integration and caching.
- Add reconciliation tools for settlement batches.
- Add export/backup and restore functionality for local DB.

Small developer-friendly improvements
- Split `admin_screen.dart` into smaller widgets/files per tab for readability.
- Add consistent theme and spacing constants.
- Remove unused imports and silence analyzer warnings gradually.

If you'd like, I can:
- Implement SharedPreferences persistence for `AppConfig` now.
- Add `agents`, `recipients`, `notifications`, and `audit` tables to `LocalDb` schema and migrate existing data.
- Run a repo-wide replacement of hard-coded currency formats.

Tell me which follow-up you'd like me to do next.
