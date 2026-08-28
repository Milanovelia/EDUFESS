import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_env.dart';
import 'core/config/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppEnv.load();
  await SupabaseBootstrap.initialize();

  runApp(const ProviderScope(child: EdufessApp()));
}
