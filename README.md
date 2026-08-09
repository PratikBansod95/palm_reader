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

## Backend (OpenRouter Gemma free vision)

1. `cd backend && npm install`
2. Copy `.env.example` to `.env`
3. Set:
   - `AI_PROVIDER=openrouter`
   - `OPENROUTER_API_KEY=...` from [OpenRouter](https://openrouter.ai/keys)
   - `OPENROUTER_MODEL=google/gemma-4-26b-a4b-it:free`
4. Optional alternatives still supported: `GEMINI_API_KEY` or `OPENAI_API_KEY`
5. `npm run dev`

Health check: `GET http://localhost:8080/api/health`

## Flutter with live backend

```bash
flutter run -d windows --dart-define=ANALYSIS_MODE=backend --dart-define=BACKEND_URL=http://127.0.0.1:8080 --dart-define=BACKEND_APP_KEY=palm-destiny-local-dev-key
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
