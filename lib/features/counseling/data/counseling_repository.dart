import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/bk_appointment.dart';
import 'models/bk_conversation.dart';
import 'models/bk_mood_checkin.dart';

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

  /// Returns the student's most recent active conversation, or null when
  /// the student legitimately has none. RPC failures propagate as typed
  /// [CounselingException] via [fetchStudentConversations]; they are never
  /// swallowed to null. RPC-only minimal projection, no direct table read.
  Future<BkConversation?> getActiveConversation() async {
    final list = await fetchStudentConversations();
    for (final c in list) {
      if (c.isActive) return c;
    }
    return null;
  }

  Future<List<BkConversation>> fetchStudentConversations() async {
    // P0-3: RPC-only minimal projection. Failures propagate as typed
    // errors; no direct full-row fallback.
    try {
      final data = await _client.rpc('get_student_bk_conversations');
      final list = data as List;
      return list.map((e) => BkConversation.fromQueueMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateQueueError(e));
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
    // P0-3: RPC-only minimal projection. Failures propagate as typed
    // errors; no direct full-row fallback.
    try {
      final data = await _client.rpc('get_counselor_assigned_conversations');
      final list = data as List;
      return list.map((e) => BkConversation.fromQueueMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateQueueError(e));
    }
  }

  Future<void> claimConversation(String conversationId) async {
    try {
      await _client.rpc('claim_counseling_conversation', params: {'p_conversation_id': conversationId});
    } catch (e) {
      throw CounselingException(_translateClaimError(e));
    }
  }

  Future<void> closeConversation(String conversationId) async {
    try {
      await _client.rpc('close_counseling_conversation', params: {'p_conversation_id': conversationId});
    } catch (e) {
      throw CounselingException(_translateCloseError(e));
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

  /// Soft-delete a counseling message the caller sent.
  /// Only the original sender may delete their own message.
  Future<void> deleteMessage(String messageId) async {
    try {
      await _client.rpc('delete_counseling_message', params: {'p_message_id': messageId});
    } catch (e) {
      throw CounselingException(_translateDeleteMessageError(e));
    }
  }

  // --------------------------------------------------------------------------
  // Availability
  // --------------------------------------------------------------------------
  Future<List<CounselorSlot>> fetchAvailableSlots() async {
    try {
      final data = await _client.rpc('get_available_counseling_slots');
      final list = data as List;
      return list.map((e) => CounselorSlot.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateAvailabilityError(e));
    }
  }

  Future<String> createAvailability({required DateTime date, required String startTime, required String endTime}) async {
    try {
      final data = await _client.rpc('create_counselor_availability', params: {
        'p_available_date': date.toIso8601String().split('T')[0],
        'p_start_time': startTime,
        'p_end_time': endTime,
      });
      return data as String;
    } catch (e) {
      throw CounselingException(_translateAvailabilityError(e));
    }
  }

  /// Updates a counselor-owned, unbooked, active, future availability slot.
  ///
  /// Server enforces ownership, active state, future date, start < end,
  /// duplicate guard, and booked-slot protection.
  Future<void> updateAvailability({required String availabilityId, required DateTime date, required String startTime, required String endTime}) async {
    try {
      await _client.rpc('update_counselor_availability', params: {
        'p_availability_id': availabilityId,
        'p_available_date': date.toIso8601String().split('T')[0],
        'p_start_time': startTime,
        'p_end_time': endTime,
      });
    } catch (e) {
      throw CounselingException(_translateAvailabilityManageError(e, 'diubah'));
    }
  }

  /// Soft-deactivates (`is_active = false`) a counselor-owned, unbooked slot
  /// so it disappears from student discovery. Never physically deletes.
  Future<void> deactivateAvailability({required String availabilityId}) async {
    try {
      await _client.rpc('deactivate_counselor_availability', params: {
        'p_availability_id': availabilityId,
      });
    } catch (e) {
      throw CounselingException(_translateAvailabilityManageError(e, 'dinonaktifkan'));
    }
  }

  Future<List<CounselorAvailability>> fetchMyAvailability() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final data = await _client.from('counselor_availability').select().eq('counselor_id', user.id).order('available_date', ascending: true);
    return (data as List).map((e) => CounselorAvailability.fromMap(e as Map<String, dynamic>)).toList();
  }

  // --------------------------------------------------------------------------
  // Appointments
  // --------------------------------------------------------------------------
  Future<List<BkAppointment>> fetchStudentAppointments() async {
    try {
      final data = await _client.rpc('get_student_bk_appointments');
      final list = data as List;
      return list.map((e) => BkAppointment.fromStudentMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  Future<List<BkAppointment>> fetchCounselorAppointments() async {
    try {
      final data = await _client.rpc('get_counselor_bk_appointments');
      final list = data as List;
      return list.map((e) => BkAppointment.fromCounselorMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  Future<String> requestAppointment({required String availabilityId, String? studentNote, String? conversationId}) async {
    try {
      final data = await _client.rpc('request_bk_appointment', params: {
        'p_availability_id': availabilityId,
        'p_student_note': studentNote,
        'p_conversation_id': conversationId,
      });
      return data as String;
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  Future<void> acceptAppointment(String appointmentId) async {
    try {
      await _client.rpc('accept_bk_appointment', params: {'p_appointment_id': appointmentId});
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  Future<void> rejectAppointment(String appointmentId, {String? reason}) async {
    try {
      await _client.rpc('reject_bk_appointment', params: {'p_appointment_id': appointmentId, 'p_reason': reason});
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  Future<void> rescheduleAppointment({required String appointmentId, required DateTime newStart, required DateTime newEnd}) async {
    try {
      await _client.rpc('reschedule_bk_appointment', params: {
        'p_appointment_id': appointmentId,
        'p_new_start_at': newStart.toIso8601String(),
        'p_new_end_at': newEnd.toIso8601String(),
      });
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  Future<void> cancelStudentAppointment(String appointmentId) async {
    try {
      await _client.rpc('cancel_student_bk_appointment', params: {'p_appointment_id': appointmentId});
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  Future<void> cancelCounselorAppointment(String appointmentId, {String? reason}) async {
    try {
      await _client.rpc('cancel_counselor_bk_appointment', params: {'p_appointment_id': appointmentId, 'p_reason': reason});
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  Future<void> completeAppointment(String appointmentId) async {
    try {
      await _client.rpc('complete_bk_appointment', params: {'p_appointment_id': appointmentId});
    } catch (e) {
      throw CounselingException(_translateAppointmentError(e));
    }
  }

  // --------------------------------------------------------------------------
  // Mood check-in
  // --------------------------------------------------------------------------
  Future<String> submitMoodCheckin({required int moodLevel, String? note}) async {
    try {
      final data = await _client.rpc('submit_bk_mood_checkin', params: {
        'p_mood_level': moodLevel,
        'p_note': note,
      });
      return data as String;
    } catch (e) {
      throw CounselingException(_translateMoodError(e));
    }
  }

  Future<List<BkMoodCheckin>> fetchStudentMoodHistory({int limit = 30, int offset = 0}) async {
    try {
      final data = await _client.rpc('get_student_bk_mood_history', params: {
        'p_limit': limit,
        'p_offset': offset,
      });
      final list = data as List;
      return list.map((e) => BkMoodCheckin.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateMoodError(e));
    }
  }

  Future<List<BkMoodCheckin>> fetchCounselorStudentMoodHistory({required String conversationId, int limit = 30, int offset = 0}) async {
    try {
      final data = await _client.rpc('get_counselor_student_mood_history', params: {
        'p_conversation_id': conversationId,
        'p_limit': limit,
        'p_offset': offset,
      });
      final list = data as List;
      return list.map((e) => BkMoodCheckin.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw CounselingException(_translateMoodError(e));
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
    if (m.contains('tidak memiliki akses')) return 'Tidak memiliki akses.';
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

  String _translateDeleteMessageError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not authenticated')) return 'Harus login.';
    if (m.contains('not your message')) return 'Kamu hanya bisa menghapus pesanmu sendiri.';
    if (m.contains('not found') || m.contains('already deleted')) return 'Pesan tidak ditemukan.';
    return 'Gagal menghapus pesan.';
  }

  String _translateRevealError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('reason required')) return 'Alasan wajib diisi.';
    if (m.contains('not assigned')) return 'Kamu bukan konselor yang menangani percakapan ini.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Akses identitas gagal.';
  }

  String _translateMoodError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('perlu menyetujui')) return 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.';
    if (m.contains('invalid mood level')) return 'Mood tidak valid.';
    if (m.contains('note too long')) return 'Catatan terlalu panjang.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal memproses mood.';
  }

  String _translateAvailabilityError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('past slot')) return 'Slot sudah lewat.';
    if (m.contains('invalid time')) return 'Waktu tidak valid.';
    if (m.contains('slot sudah ada')) return 'Slot sudah ada.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal mengelola ketersediaan.';
  }

  /// Maps edit/deactivate failures. [action] is 'diubah' or 'dinonaktifkan'.
  String _translateAvailabilityManageError(Object e, String action) {
    final m = e.toString().toLowerCase();
    if (m.contains('sudah dipesan')) return 'Slot ini sudah dipesan sehingga tidak bisa $action.';
    if (m.contains('tidak ditemukan') || m.contains('not found')) return 'Slot tidak ditemukan.';
    if (m.contains('tidak aktif')) return 'Slot sudah tidak aktif.';
    if (m.contains('past slot')) return 'Slot sudah lewat.';
    if (m.contains('invalid time')) return 'Waktu tidak valid.';
    if (m.contains('slot sudah ada')) return 'Slot sudah ada.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal mengelola ketersediaan.';
  }

  String _translateAppointmentError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('perlu menyetujui')) return 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.';
    if (m.contains('slot sudah dipesan')) return 'Slot sudah dipesan.';
    if (m.contains('slot tidak tersedia')) return 'Slot tidak tersedia.';
    if (m.contains('past slot') || m.contains('past schedule')) return 'Waktu sudah lewat.';
    if (m.contains('invalid time') || m.contains('invalid schedule')) return 'Waktu tidak valid.';
    if (m.contains('duration too long')) return 'Durasi terlalu lama.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not found')) return 'Janji tidak ditemukan.';
    if (m.contains('only pending')) return 'Hanya janji pending yang bisa diproses.';
    if (m.contains('only assigned')) return 'Hanya janji yang ditangani bisa diselesaikan.';
    if (m.contains('only accepted')) return 'Hanya janji ter-jadwal bisa diselesaikan.';
    if (m.contains('cannot cancel')) return 'Tidak bisa membatalkan.';
    if (m.contains('conflicting')) return 'Jadwal bentrok.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal memproses janji.';
  }

  String _translateCloseError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not assigned')) return 'Kamu bukan konselor yang menangani percakapan ini.';
    if (m.contains('already closed')) return 'Percakapan sudah selesai.';
    if (m.contains('only assigned')) return 'Hanya percakapan yang ditangani bisa diselesaikan.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    if (m.contains('not authenticated')) return 'Harus login.';
    if (m.contains('not found')) return 'Percakapan tidak ditemukan.';
    return 'Gagal menyelesaikan percakapan.';
  }

  // --------------------------------------------------------------------------
  // Mood soft-delete (student only, own data via security-definer RPC)
  // --------------------------------------------------------------------------

  /// Soft-deletes a mood check-in. Server validates ownership and student role.
  Future<void> deleteMoodCheckin(String checkinId) async {
    try {
      await _client.rpc('delete_mood_checkin', params: {'p_checkin_id': checkinId});
    } catch (e) {
      throw CounselingException(_translateMoodDeleteError(e));
    }
  }

  String _translateMoodDeleteError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not found') || m.contains('already deleted')) return 'Check-in tidak ditemukan atau sudah dihapus.';
    if (m.contains('not authorized')) return 'Kamu hanya bisa menghapus check-in milikmu.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal menghapus check-in.';
  }
}

class CounselingException implements Exception {
  const CounselingException(this.message);
  final String message;
  @override
  String toString() => 'CounselingException: $message';
}
