import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/moderation_report.dart';

/// Data access for M5 moderation.
class ModerationRepository {
  ModerationRepository(this._client);
  final SupabaseClient _client;

  /// Student report. Throws [ReportException] with Indonesian message.
  Future<String> reportContent({
    required String targetType,
    String? postId,
    String? commentId,
    required String reason,
    String? details,
  }) async {
    try {
      final data = await _client.rpc('report_content', params: {
        'p_target_type': targetType,
        'p_post_id': postId,
        'p_comment_id': commentId,
        'p_reason': reason,
        'p_details': details,
      });
      return data as String;
    } catch (e) {
      throw ReportException(_translateReportError(e));
    }
  }

  /// Admin queue — privacy-safe, only admin succeeds.
  Future<List<ModerationReport>> fetchQueue() async {
    try {
      final data = await _client.rpc('get_moderation_queue');
      final list = data as List;
      return list.map((e) => ModerationReport.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ReportException(_translateQueueError(e));
    }
  }

  /// Admin moderate: dismiss or remove.
  Future<void> moderateReport({
    required String reportId,
    required String action, // dismiss_report | remove_content
    String? reason,
  }) async {
    try {
      await _client.rpc('moderate_report', params: {
        'p_report_id': reportId,
        'p_action': action,
        'p_reason': reason,
      });
    } catch (e) {
      throw ReportException(_translateModerateError(e));
    }
  }

  String _translateReportError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('sudah pernah kamu laporkan')) return 'Konten ini sudah pernah kamu laporkan dan masih ditinjau.';
    if (m.contains('invalid target type')) return 'Tipe target tidak valid.';
    if (m.contains('invalid reason')) return 'Alasan tidak valid.';
    if (m.contains('post not found') || m.contains('comment not found')) return 'Konten tidak ditemukan.';
    if (m.contains('post has been deleted') || m.contains('comment has been deleted')) return 'Konten sudah dihapus.';
    if (m.contains('not authenticated')) return 'Harus login.';
    if (m.contains('details too long')) return 'Detail terlalu panjang.';
    if (m.contains('not authorized')) return 'Tidak memiliki izin.';
    return 'Laporan gagal dikirim.';
  }

  String _translateQueueError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not authenticated')) return 'Harus login.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses moderasi.';
    return 'Gagal memuat antrean moderasi.';
  }

  String _translateModerateError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('not authenticated')) return 'Harus login.';
    if (m.contains('not authorized')) return 'Tidak memiliki akses moderasi.';
    if (m.contains('report not found')) return 'Laporan tidak ditemukan.';
    if (m.contains('already processed')) return 'Laporan sudah diproses.';
    if (m.contains('invalid action')) return 'Aksi tidak valid.';
    return 'Tindakan moderasi gagal.';
  }
}

class ReportException implements Exception {
  const ReportException(this.message);
  final String message;
  @override
  String toString() => 'ReportException: $message';
}
