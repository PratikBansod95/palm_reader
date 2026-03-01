# Palm Reader

Flutter app for palm-reading style analysis with a secure backend proxy to OpenAI.

## Architecture

- `lib/` Flutter client app
- `backend/` Node.js API that holds OpenAI key and performs model call

The mobile app **does not call OpenAI directly** anymore.

## Backend Setup

1. Open terminal in `backend/`
2. Install deps:
   - `npm install`
3. Create env file from template:
   - copy `.env.example` to `.env`
4. Set values in `.env`:
   - `OPENAI_API_KEY=...`
   - `OPENAI_MODEL=gpt-4.1-nano` (optional)
   - `PORT=8080` (optional)
   - `CORS_ORIGIN=https://your-frontend.example.com` (comma-separated allowed origins)
   - `OPENAI_TIMEOUT_MS=45000` (optional)
   - `APP_API_KEY=replace-with-strong-random-token` (recommended)
5. Run backend:
   - `npm run dev`

Health check:
- `GET http://localhost:8080/api/health`

## Flutter Setup

1. In project root:
   - `flutter pub get`
2. Run app with backend URL:
   - Hosted backend: `flutter run --dart-define=BACKEND_URL=https://your-backend.onrender.com --dart-define=BACKEND_APP_KEY=replace-with-strong-random-token`
   - Android emulator local: `flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8080 --dart-define=BACKEND_APP_KEY=replace-with-strong-random-token`
   - Physical device local: `flutter run --dart-define=BACKEND_URL=http://<YOUR_PC_LAN_IP>:8080 --dart-define=BACKEND_APP_KEY=replace-with-strong-random-token`

## API Contract

### `POST /api/palm-reading`

Multipart form-data:
- `image` (required, image file)
- `language` (required)
- `dominantHand` (required)

Response:
```json
{ "reading": "...natural narrative text..." }
```

## Security Notes

- Keep OpenAI API key only on backend (`backend/.env`)
- Use `APP_API_KEY` + rate limiting as baseline access control
- Restrict `CORS_ORIGIN` and deploy over HTTPS
