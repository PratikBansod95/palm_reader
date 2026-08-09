# Palm Destiny

Frontend-first Flutter palm reading app. **No backend required** for normal use.

## How analysis works

1. **OpenRouter (recommended for you)** — app calls `google/gemma-4-26b-a4b-it:free` directly
2. **Demo fallback** — offline narrative if no OpenRouter key is configured
3. **Backend (optional later)** — `backend/` remains in the repo when you want a secure proxy

## Quick start (live AI, frontend only)

1. Put your OpenRouter key in `.secrets/openrouter.key` (one line, already gitignored)
2. Run:

```powershell
.\run_app.ps1
# or another device:
.\run_app.ps1 -d chrome
```

## Offline demo only

```bash
flutter pub get
flutter run -d windows
```

## Optional backend later

When you want keys off-device:

```bash
cd backend
# configure .env
npm run dev
flutter run --dart-define=ANALYSIS_MODE=backend --dart-define=BACKEND_URL=http://127.0.0.1:8080 --dart-define=BACKEND_APP_KEY=...
```

## Security note

Frontend OpenRouter keys can be extracted from a distributed app binary. Fine for a personal build that stays with you. Use the backend before any public/store release.
