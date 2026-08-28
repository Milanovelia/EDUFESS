import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal profile model matching the `public.profiles` table.
///
/// Only contains fields that C2 exposes. Email is intentionally absent —
/// it lives in `auth.users` and never enters the public profile model.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.pseudonym,
    required this.role,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      pseudonym: map['pseudonym'] as String,
      role: map['role'] as String,
    );
  }

  final String id;
  final String pseudonym;
  final String role;

  bool get isStudent => role == 'student';
  bool get isCounselor => role == 'counselor';
  bool get isAdmin => role == 'admin';
}

/// Fetches the current user's own profile from `public.profiles`.
///
/// Uses `profiles.id = auth.uid()` — RLS ensures users can only
/// read their own row.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  /// Fetches the profile for the currently authenticated user.
  ///
  /// Returns `null` if no profile exists (should not happen after
  /// successful signup, but handled gracefully).
  Future<UserProfile?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select('id, pseudonym, role')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromMap(data);
  }
}
