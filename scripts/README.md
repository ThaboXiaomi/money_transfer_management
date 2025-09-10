PowerShell wrapper: flutter_run.ps1

What it does
- Lists connected Flutter devices using `flutter devices --machine`.
- Prompts you to pick one by index.
- Runs `flutter run -d <deviceId>` with any extra args you pass after `--`.

How to use
1. From the project root run (PowerShell):

   ./scripts/flutter_run.ps1 -- <additional flutter args>

   Example: ./scripts/flutter_run.ps1 -- --profile

Notes
- Make sure `flutter` is available in your PATH.
- If you hit Enter at the selection prompt the script cancels without running.
- This avoids Flutter auto-selecting a recently connected device when you run `flutter run` directly.
