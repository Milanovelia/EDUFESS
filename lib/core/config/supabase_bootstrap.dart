import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import 'app_env.dart';

/// Starts the Supabase SDK once, before `runApp`.
///
/// M0 scope: initialization only. No auth flow, no queries, no tables.
/// Authorization for every future feature is enforced server-side (RLS),
/// never by the Flutter layer.
abstract final class SupabaseBootstrap {
  static bool _isInitialized = false;

  /// Whether a Supabase client is available for use.
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (!AppEnv.isSupabaseConfigured) {
      debugPrint(
        '[Edufess] Supabase env not configured; starting without a backend. '
        'See README > Environment configuration.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: AppEnv.supabaseUrl,
        publishableKey: AppEnv.supabaseAnonKey,
      );
      _isInitialized = true;
    } on Object catch (error) {
      throw BootstrapException('Supabase initialization failed: $error');
    }
  }
}
