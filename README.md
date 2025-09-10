# money_transfer_management

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Run backend (local)

Open a PowerShell terminal in `backend/` and follow `backend/README.md` — create a venv, pip install requirements, then run:

```powershell
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Then in the Flutter project root:

```powershell
flutter pub get
flutter run
```

Set `lib/services/config.dart` `backendBase` to `http://10.0.2.2:8000` for Android emulator or to `http://localhost:8000` for desktop/iOS simulator.
