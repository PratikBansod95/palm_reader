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
   - `OPENAI_MODEL=gpt-4.1-mini` (optional)
   - `PORT=8080` (optional)
   - `CORS_ORIGIN=*` (tighten in production)
5. Run backend:
   - `npm run dev`

Health check:
- `GET http://localhost:8080/api/health`

## Flutter Setup

1. In project root:
   - `flutter pub get`
2. Run app with backend URL:
   - Android emulator: `flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8080`
   - Physical device: `flutter run --dart-define=BACKEND_URL=http://<YOUR_PC_LAN_IP>:8080`

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
- Add authentication + stronger per-user limits before production use
- Restrict `CORS_ORIGIN` and deploy over HTTPS
