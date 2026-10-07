import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/bk_peer_concern.dart';

class PeerConcernRepository {
  PeerConcernRepository(this._client);
  final SupabaseClient _client;

  Future<List<PeerStudent>> searchPeers(String query, {int limit = 10}) async {
    try {
      final data = await _client.rpc('search_peer_students', params: {'p_query': query, 'p_limit': limit});
      final list = data as List;
      return list.map((e) => PeerStudent.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw PeerConcernException(_translateSearchError(e));
    }
  }

  Future<String> submit({required String targetStudentRef, required String reason, String? details}) async {
    try {
      final data = await _client.rpc('submit_bk_peer_concern', params: {
        'p_target_student_id': targetStudentRef,
        'p_reason': reason,
        'p_details': details,
      });
      return data as String;
    } catch (e) {
      throw PeerConcernException(_translateSubmitError(e));
    }
  }

  Future<List<BkPeerConcern>> fetchStudentHistory() async {
    try {
      final data = await _client.rpc('get_student_peer_concerns');
      final list = data as List;
      return list.map((e) => BkPeerConcern.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw PeerConcernException(_translateHistoryError(e));
    }
  }

  Future<List<BkPeerConcern>> fetchCounselorQueue() async {
    try {
      final data = await _client.rpc('get_counselor_peer_concern_queue');
      final list = data as List;
      return list.map((e) => BkPeerConcern.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw PeerConcernException(_translateQueueError(e));
    }
  }

  Future<BkPeerConcern> fetchDetail(String concernId) async {
    try {
      final data = await _client.rpc('get_counselor_peer_concern_detail', params: {'p_concern_id': concernId});
      final list = data as List;
      if (list.isEmpty) throw const PeerConcernException('Tidak ditemukan.');
      return BkPeerConcern.fromMap(list.first as Map<String, dynamic>);
    } catch (e) {
      if (e is PeerConcernException) rethrow;
      throw PeerConcernException(_translateDetailError(e));
    }
  }

  Future<List<BkPeerConcern>> fetchCounselorHistory() async {
    try {
      final data = await _client.rpc('get_counselor_peer_concern_history');
      final list = data as List;
      return list.map((e) => BkPeerConcern.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw PeerConcernException(_translateHistoryError(e));
    }
  }

  Future<void> claim(String concernId) async {
    try {
      await _client.rpc('claim_bk_peer_concern', params: {'p_concern_id': concernId});
    } catch (e) {
      throw PeerConcernException(_translateClaimError(e));
    }
  }

  Future<void> resolve(String concernId, {String? note, String? response}) async {
    try {
      await _client.rpc('resolve_bk_peer_concern', params: {'p_concern_id': concernId, 'p_resolution_note': note, 'p_reporter_response': response});
    } catch (e) {
      throw PeerConcernException(_translateResolveError(e));
    }
  }

  Future<void> dismiss(String concernId, {String? note, String? response}) async {
    try {
      await _client.rpc('dismiss_bk_peer_concern', params: {'p_concern_id': concernId, 'p_resolution_note': note, 'p_reporter_response': response});
    } catch (e) {
      throw PeerConcernException(_translateResolveError(e));
    }
  }

  Future<void> withdrawConcern(String concernId) async {
    try {
      await _client.rpc('withdraw_bk_peer_concern', params: {'p_concern_id': concernId});
    } catch (e) {
      throw PeerConcernException(_translateWithdrawError(e));
    }
  }

  String _translateSearchError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('too short')) return 'Kata kunci minimal 2 karakter.';
    if (m.contains('not authenticated')) return 'Harus login.';
    return 'Gagal mencari teman.';
  }

  String _translateSubmitError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('perlu menyetujui')) return 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.';
    if (m.contains('cannot report self')) return 'Tidak bisa melaporkan diri sendiri.';
    if (m.contains('target must be student')) return 'Target harus siswa.';
    if (m.contains('already have')) return 'Kamu sudah memiliki laporan aktif untuk teman ini.';
    if (m.contains('sudah memiliki laporan aktif')) return 'Kamu sudah memiliki laporan aktif untuk teman ini.';
    if (m.contains('invalid reason')) return 'Alasan tidak valid.';
    if (m.contains('details too long')) return 'Detail terlalu panjang.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    return 'Gagal mengirim kepedulian.';
  }

  String _translateHistoryError(Object e) => 'Gagal memuat riwayat.';
  String _translateQueueError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    return 'Gagal memuat antrean.';
  }

  String _translateDetailError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not assigned')) return 'Kamu bukan penangan laporan ini.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    return 'Gagal memuat detail.';
  }

  String _translateClaimError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('sudah ditangani')) return 'Laporan ini sudah ditangani guru BK lain.';
    if (m.contains('only pending')) return 'Hanya laporan pending yang bisa diklaim.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    return 'Gagal mengklaim laporan.';
  }

  String _translateResolveError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not assigned')) return 'Kamu bukan penangan laporan ini.';
    if (m.contains('only pending')) return 'Hanya laporan yang sedang ditinjau bisa diselesaikan.';
    if (m.contains('note too long') || m.contains('response too long')) return 'Catatan terlalu panjang.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses.';
    return 'Gagal memproses laporan.';
  }

  String _translateWithdrawError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('sudah mulai ditangani')) return 'Laporan sudah mulai ditangani dan tidak dapat ditarik.';
    if (m.contains('sudah ditarik')) return 'Laporan ini sudah ditarik.';
    if (m.contains('sudah selesai')) return 'Laporan yang sudah selesai tidak dapat ditarik.';
    if (m.contains('not found')) return 'Laporan tidak ditemukan.';
    if (m.contains('not authorized')) return 'Kamu tidak memiliki akses untuk menarik laporan ini.';
    return 'Gagal menarik laporan.';
  }
}

class PeerConcernException implements Exception {
  const PeerConcernException(this.message);
  final String message;
  @override
  String toString() => 'PeerConcernException: $message';
}
