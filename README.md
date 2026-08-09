# Palm Destiny

Flutter app for palm-reading style analysis. Default analysis runs in **demo mode** (offline, no API key). A secure backend proxy supports **Gemini** (free tier) or OpenAI when you are ready.

## Architecture

- `lib/` Flutter client
- `backend/` Node.js API that holds AI keys and performs the model call

The mobile app **does not** call Gemini/OpenAI directly when using backend mode.

## Quick start (demo — works offline)

```bash
flutter pub get
flutter run -d windows
# or
flutter run -d chrome
```

Demo is the default (`ANALYSIS_MODE=demo`). Flow: language/hand → camera or gallery → scan → reading.

## Backend (Gemini or OpenAI)

1. `cd backend && npm install`
2. Copy `.env.example` to `.env`
3. Set either:
   - `GEMINI_API_KEY=...` from [Google AI Studio](https://aistudio.google.com/apikey) (recommended free tier)
   - or `OPENAI_API_KEY=...`
4. Optional: `AI_PROVIDER=gemini` or `openai`
5. `npm run dev`

Health check: `GET http://localhost:8080/api/health`

## Flutter with live backend

```bash
flutter run --dart-define=ANALYSIS_MODE=backend --dart-define=BACKEND_URL=http://127.0.0.1:8080 --dart-define=BACKEND_APP_KEY=replace-with-strong-random-token
```

Android emulator local backend: `BACKEND_URL=http://10.0.2.2:8080`

## API contract

### `POST /api/palm-reading`

Multipart form-data:

- `image` (required)
- `language` (required)
- `dominantHand` (required)

Response:

```json
{ "reading": "...natural narrative text..." }
```

## Security

- Keep AI keys only in `backend/.env`
- Use `APP_API_KEY` + rate limiting
- Restrict `CORS_ORIGIN` in production and deploy over HTTPS
