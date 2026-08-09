import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSecrets.load();
  runApp(const ProviderScope(child: PalmDestinyApp()));
}
