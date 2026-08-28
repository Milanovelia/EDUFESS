import 'package:edufess/features/auth/data/auth_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('translateAuthError', () {
    test('translates invalid login credentials', () {
      final error = translateAuthError(
        Exception('Invalid login credentials'),
      );
      expect(error, isA<InvalidCredentialsException>());
      expect(error.message, 'Email atau kata sandi salah.');
    });

    test('translates already registered', () {
      final error = translateAuthError(
        Exception('User already registered'),
      );
      expect(error, isA<EmailAlreadyRegisteredException>());
    });

    test('translates duplicate pseudonym', () {
      final error = translateAuthError(
        Exception('pseudonym already exists'),
      );
      expect(error, isA<PseudonymTakenException>());
    });

    test('translates invalid invitation', () {
      final error = translateAuthError(
        Exception('invitation code invalid'),
      );
      expect(error, isA<InvalidInvitationException>());
    });

    test('translates already used invitation', () {
      final error = translateAuthError(
        Exception('invitation code already used'),
      );
      expect(error, isA<InvalidInvitationException>());
    });

    test('translates missing pseudonym', () {
      final error = translateAuthError(
        Exception('Registration requires a pseudonym'),
      );
      expect(error, isA<PseudonymRequiredException>());
    });

    test('translates missing invitation', () {
      final error = translateAuthError(
        Exception('Registration requires an invitation code'),
      );
      expect(error, isA<InvitationRequiredException>());
    });

    test('translates invalid pseudonym format', () {
      final error = translateAuthError(
        Exception('Pseudonym must be 3-32 characters'),
      );
      expect(error, isA<InvalidPseudonymFormatException>());
    });

    test('returns generic for unknown errors', () {
      final error = translateAuthError(
        Exception('Something unexpected happened'),
      );
      expect(error, isA<AuthGenericException>());
      expect(error.message, contains('Something unexpected'));
    });
  });
}
