import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app/app.dart';
import 'core/config/app_env.dart';
import 'core/config/supabase_bootstrap.dart';

// Marionette is active in debug builds only (never in release) and skipped
// under `flutter test` to respect the single-binding rule.
final _isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');

Future<void> main() async {
  if (kDebugMode && !_isFlutterTest) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  await AppEnv.load();
  await SupabaseBootstrap.initialize();

  runApp(const ProviderScope(child: EdufessApp()));
}
