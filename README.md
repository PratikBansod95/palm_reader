# Palm Destiny

Personal Flutter palm-reading app. **No backend required.**

Live AI uses OpenRouter (`google/gemma-4-26b-a4b-it:free`) from the app.

## One-time key setup (required for phone installs)

1. Copy the example key file:

```powershell
Copy-Item lib\config\openrouter_embedded.example.dart lib\config\openrouter_embedded.dart
```

2. Paste your OpenRouter key into `lib/config/openrouter_embedded.dart`:

```dart
const String kEmbeddedOpenRouterApiKey = 'sk-or-v1-...';
```

That key is **compiled into the APK**, so Android Studio Run / phone installs get Live AI without extra dart-defines.

`openrouter_embedded.dart` is gitignored (not pushed to GitHub).

## Run

```powershell
flutter pub get
flutter run -d windows
# phone:
flutter run -d <device_id>
```

On the home screen, tap **Check** — you should see **AI is working**.

## Offline demo only

```powershell
flutter run --dart-define=ANALYSIS_MODE=demo
```
