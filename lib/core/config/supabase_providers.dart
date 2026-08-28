import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import 'supabase_bootstrap.dart';

/// Single access point to the Supabase client for the whole app.
///
/// Features must depend on this provider instead of calling
/// `Supabase.instance` directly, so it can be overridden in tests.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!SupabaseBootstrap.isInitialized) {
    throw const ConfigException(
      'Supabase is not initialized. Configure .env and restart the app.',
    );
  }
  return Supabase.instance.client;
});
