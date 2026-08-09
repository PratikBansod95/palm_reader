# Palm Destiny

Personal Flutter palm-reading app. **No backend required.**

For demos/presentations, the app calls OpenRouter (`google/gemma-4-26b-a4b-it:free`) directly and returns a **real AI palm reading**.

## Setup (once)

1. Put your OpenRouter key in:

```text
.secrets/openrouter.key
```

(one line, already gitignored)

2. Install deps:

```bash
flutter pub get
```

## Run (real AI results)

```bash
flutter run -d windows
# or
flutter run -d chrome
# or
.\run_app.ps1
```

On launch the app loads `.secrets/openrouter.key` automatically, then:

**language/hand → camera/gallery → scan → live OpenRouter reading**

## Offline placeholder only

If you intentionally want fake offline text:

```bash
flutter run -d windows --dart-define=ANALYSIS_MODE=demo
```

## Backend later (optional)

`backend/` remains in the repo for a future secure proxy. Not needed while the app stays private with you.
