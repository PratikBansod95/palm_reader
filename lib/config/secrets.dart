import 'package:flutter/foundation.dart';

import 'openrouter_embedded.dart';
import 'secrets_loader_stub.dart'
    if (dart.library.io) 'secrets_loader_io.dart' as loader;

/// Personal OpenRouter credentials for frontend-only demos.
///
/// Load order:
/// 1) `--dart-define=OPENROUTER_API_KEY=...`
/// 2) baked-in key from `openrouter_embedded.dart`
/// 3) `.secrets/openrouter.key` (desktop/dev only)
class AppSecrets {
  AppSecrets._();

  static String openRouterApiKey = '';

  static const _fromDefine = String.fromEnvironment('OPENROUTER_API_KEY');

  static Future<void> load() async {
    if (_fromDefine.trim().isNotEmpty) {
      openRouterApiKey = _fromDefine.trim();
      return;
    }

    if (kEmbeddedOpenRouterApiKey.trim().isNotEmpty) {
      openRouterApiKey = kEmbeddedOpenRouterApiKey.trim();
      return;
    }

    if (kIsWeb) {
      return;
    }

    openRouterApiKey = await loader.loadOpenRouterKeyFromDisk();
  }

  static bool get hasOpenRouterKey => openRouterApiKey.trim().isNotEmpty;
}

/// Backwards-compatible getter used by analysis service.
String get openRouterApiKey {
  if (AppSecrets.openRouterApiKey.trim().isNotEmpty) {
    return AppSecrets.openRouterApiKey.trim();
  }
  if (AppSecrets._fromDefine.trim().isNotEmpty) {
    return AppSecrets._fromDefine.trim();
  }
  return kEmbeddedOpenRouterApiKey.trim();
}
