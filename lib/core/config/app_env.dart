import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../errors/app_exception.dart';

/// Environment configuration for Edufess.
///
/// Values are read from a local `.env` file (git-ignored). Never hardcode
/// credentials in source: `.env.example` documents the required keys.
abstract final class AppEnv {
  static const String fileName = '.env';

  static const String supabaseUrlKey = 'SUPABASE_URL';
  static const String supabaseAnonKeyKey = 'SUPABASE_ANON_KEY';

  /// Loads `.env` if present. Missing file is tolerated so the app still runs
  /// (backend-less) during early milestones.
  static Future<void> load() =>
      dotenv.load(fileName: fileName, isOptional: true);

  /// True when every key required to talk to Supabase is present.
  static bool get isSupabaseConfigured =>
      _maybeRead(supabaseUrlKey) != null &&
      _maybeRead(supabaseAnonKeyKey) != null;

  static String get supabaseUrl => _read(supabaseUrlKey);

  static String get supabaseAnonKey => _read(supabaseAnonKeyKey);

  static String? _maybeRead(String key) {
    if (!dotenv.isInitialized) return null;
    final value = dotenv.maybeGet(key)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String _read(String key) {
    final value = _maybeRead(key);
    if (value == null) {
      throw ConfigException(
        'Missing "$key". Copy .env.example to .env and fill in the values.',
      );
    }
    return value;
  }
}
