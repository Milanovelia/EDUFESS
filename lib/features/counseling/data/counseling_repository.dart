import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/bk_conversation.dart';

class CounselingRepository {
  CounselingRepository(this._client);
  final SupabaseClient _client;

  // --------------------------------------------------------------------------
  // Consent
  // --------------------------------------------------------------------------
  Future<bool> hasActiveConsent() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final data = await _client
        .from('bk_consents')
        .select('id')
        .eq('student_id', user.id)
        .eq('version', 'bk-consent-v1')
        .isFilter('revoked_at', null)
        .maybeSingle();
    return data != null;
  }

  Future<void> createConsent() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const CounselingException('Harus login.');
    try {
      await _client.from('bk_consents').insert({
        'student_id': user.id,
        'version': 'bk-consent-v1',
      });
    } catch (e) {
      throw CounselingException(_translateConsentError(e));
    }
  }

  // --------------------------------------------------------------------------
  // Conversations
  // --------------------------------------------------------------------------
  Future<String> createConversation() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const CounselingException('Harus login.');
    try {
      final data = await _client
          .from('counseling_conversations')
          .insert({'student_id': user.id, 'student_alias': 'temp'})
          .select('id')
          .single();
      return data['id'] as String;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('sudah memiliki percakapan aktif') || msg.contains('one_active') || msg.contains('duplicate')) {
        // Try to return existing active conversation
        try {
          final existing = await _client
              .from('counseling_conversations')
              .select('id')
              .eq('student_id', user.id)
              .inFilter('status', ['open', 'assigned'])
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (existing != null) return existing['id'] as String;
        } catch (_) {}
      }
      throw CounselingException(_translateConversationError(e));
    }
  }

  Future<BkConversation?> getActiveConversation() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('counseling_conversations')
          .select()
          .eq('student_id', user.id)
          .inFilter('status', ['open', 'assigned'])
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return BkConversation.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<BkConversation>> fetchStudentConversations() async {
    try {
      final data = await _client.rpc('get_student_bk_conversations');
      final list = data as List;
      return list.map((e) => BkConversation.fromQueueMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // fallback direct (should not happen)
      final user = _client.auth.currentUser;
      if (user == null) return [];
      final data = await _client.from('counseling_conversations').select().eq('student_id', user.id).order('created_at', ascending: false);
      return (data as List).map((e) => BkConversation.fromMap(e as Map<String, dynamic>)).toList();
    }
  }

  Future<List<BkConversation>> fetchCounselorQueue() async {
    try {
      final data = await _client.rpc('get_counselor_bk_queue');
      final list = data as List;
      return list.map((e) => BkConversation.fromQueueMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateQueueError(e));
    }
  }

  Future<List<BkConversation>> fetchCounselorAssigned() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final data = await _client.from('counseling_conversations').select().eq('counselor_id', user.id).order('created_at', ascending: false);
    return (data as List).map((e) => BkConversation.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> claimConversation(String conversationId) async {
    try {
      await _client.rpc('claim_counseling_conversation', params: {'p_conversation_id': conversationId});
    } catch (e) {
      throw CounselingException(_translateClaimError(e));
    }
  }

  // --------------------------------------------------------------------------
  // Messages
  // --------------------------------------------------------------------------
  Future<List<BkMessage>> fetchMessages(String conversationId) async {
    try {
      final data = await _client.rpc('get_counseling_messages', params: {'p_conversation_id': conversationId});
      final list = data as List;
      return list.map((e) => BkMessage.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateMessageError(e));
    }
  }

  Future<void> sendMessage({required String conversationId, required String content}) async {
    try {
      await _client.rpc('send_counseling_message', params: {'p_conversation_id': conversationId, 'p_content': content});
    } catch (e) {
      throw CounselingException(_translateMessageError(e));
    }
  }

  // --------------------------------------------------------------------------
  // Identity reveal
  // --------------------------------------------------------------------------
  Future<({String studentId, String pseudonym})> revealIdentity({required String conversationId, required String reason}) async {
    try {
      final data = await _client.rpc('reveal_counseling_identity', params: {'p_conversation_id': conversationId, 'p_reason': reason});
      final list = data as List;
      if (list.isEmpty) throw const CounselingException('Akses identitas gagal.');
      final row = list.first as Map<String, dynamic>;
      return (studentId: row['student_id'] as String, pseudonym: row['pseudonym'] as String);
    } catch (e) {
      if (e is CounselingException) rethrow;
      throw CounselingException(_translateRevealError(e));
    }
  }

  // --------------------------------------------------------------------------
  // Translators
  // --------------------------------------------------------------------------
  String _translateConsentError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('only student')) return 'Hanya siswa yang bisa memberi persetujuan.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal menyimpan persetujuan.';
  }

  String _translateConversationError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('perlu menyetujui')) return 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.';
    if (m.contains('only student')) return 'Hanya siswa yang bisa membuat percakapan.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal membuat percakapan.';
  }

  String _translateQueueError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal memuat antrean.';
  }

  String _translateClaimError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('sudah ditangani')) return 'Percakapan ini sudah ditangani guru BK lain.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not authenticated')) return 'Harus login.';
    if (m.contains('not found')) return 'Percakapan tidak ditemukan.';
    return 'Gagal mengklaim percakapan.';
  }

  String _translateMessageError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('tidak memiliki akses')) return 'Kamu tidak memiliki akses ke percakapan ini.';
    if (m.contains('perlu menyetujui')) return 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.';
    if (m.contains('not authenticated')) return 'Harus login.';
    if (m.contains('invalid')) return 'Pesan tidak valid.';
    return 'Pesan gagal dikirim.';
  }

  String _translateRevealError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('reason required')) return 'Alasan wajib diisi.';
    if (m.contains('not assigned')) return 'Kamu bukan konselor yang menangani percakapan ini.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Akses identitas gagal.';
  }
}

class CounselingException implements Exception {
  const CounselingException(this.message);
  final String message;
  @override
  String toString() => 'CounselingException: $message';
}
