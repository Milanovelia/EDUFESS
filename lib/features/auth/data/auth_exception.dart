/// Auth-specific errors for EduFess C2.
///
/// Supabase errors are caught and translated into these types so the
/// presentation layer can show user-friendly Indonesian messages without
/// leaking raw database details.
sealed class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Email or password is incorrect.
final class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException()
      : super('Email atau kata sandi salah.');
}

/// Email is already registered.
final class EmailAlreadyRegisteredException extends AuthException {
  const EmailAlreadyRegisteredException()
      : super('Email sudah terdaftar. Silakan gunakan email lain atau masuk.');
}

/// Pseudonym is already taken (case-insensitive).
final class PseudonymTakenException extends AuthException {
  const PseudonymTakenException()
      : super('Pseudonim sudah digunakan. Silakan pilih yang lain.');
}

/// Invitation code is invalid or already used.
final class InvalidInvitationException extends AuthException {
  const InvalidInvitationException()
      : super('Kode undangan tidak valid atau sudah digunakan.');
}

/// Email format is invalid.
final class InvalidEmailException extends AuthException {
  const InvalidEmailException()
      : super('Format email tidak valid.');
}

/// Signup requires a pseudonym (missing from metadata).
final class PseudonymRequiredException extends AuthException {
  const PseudonymRequiredException()
      : super('Pseudonim wajib diisi.');
}

/// Signup requires an invitation code (missing from metadata).
final class InvitationRequiredException extends AuthException {
  const InvitationRequiredException()
      : super('Kode undangan wajib diisi.');
}

/// Pseudonym format is invalid (3-32 chars, A-Za-z0-9_.-).
final class InvalidPseudonymFormatException extends AuthException {
  const InvalidPseudonymFormatException()
      : super('Pseudonim harus 3-32 karakter (huruf, angka, _ . -).');
}

/// Generic auth failure that doesn't fit other categories.
final class AuthGenericException extends AuthException {
  const AuthGenericException(super.message);
}

/// Translates raw Supabase/Auth errors into [AuthException] types.
AuthException translateAuthError(Object error) {
  final message = error.toString().toLowerCase();

  if (message.contains('invalid login credentials') ||
      message.contains('invalid email or password')) {
    return const InvalidCredentialsException();
  }
  if (message.contains('already registered') ||
      message.contains('user already exists')) {
    return const EmailAlreadyRegisteredException();
  }
  if (message.contains('pseudonym') && message.contains('already')) {
    return const PseudonymTakenException();
  }
  if (message.contains('invitation') &&
      (message.contains('invalid') || message.contains('already used'))) {
    return const InvalidInvitationException();
  }
  if (message.contains('pseudonym') && message.contains('3-32')) {
    return const InvalidPseudonymFormatException();
  }
  if (message.contains('registration requires a pseudonym')) {
    return const PseudonymRequiredException();
  }
  if (message.contains('registration requires an invitation')) {
    return const InvitationRequiredException();
  }
  if (message.contains('invalid invitation code')) {
    return const InvalidInvitationException();
  }

  return AuthGenericException(error.toString());
}
