/// OpenRouter key for frontend-only mode.
///
/// Provide via:
/// - `.\run_app.ps1` (reads `.secrets/openrouter.key`), or
/// - `--dart-define=OPENROUTER_API_KEY=...`
const String openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');
