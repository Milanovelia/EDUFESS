/// Base type for every failure Edufess raises on purpose.
///
/// Kept intentionally small for M0: only bootstrap/configuration failures
/// exist yet. Feature-level failures are added by the milestone that needs
/// them instead of being predicted here.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Missing or invalid environment configuration (e.g. empty `SUPABASE_URL`).
final class ConfigException extends AppException {
  const ConfigException(super.message);
}

/// A required service failed to start during app bootstrap.
final class BootstrapException extends AppException {
  const BootstrapException(super.message);
}
