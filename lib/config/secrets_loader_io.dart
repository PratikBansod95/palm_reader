import 'dart:io';

Future<String> loadOpenRouterKeyFromDisk() async {
  final candidates = <File>[
    File('.secrets/openrouter.key'),
    File('openrouter.key'),
  ];

  try {
    final exeDir = File(Platform.resolvedExecutable).parent;
    candidates.add(
      File('${exeDir.path}${Platform.pathSeparator}openrouter.key'),
    );
  } catch (_) {}

  for (final file in candidates) {
    try {
      if (await file.exists()) {
        final value = (await file.readAsString()).trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    } catch (_) {
      // Try next candidate.
    }
  }
  return '';
}
