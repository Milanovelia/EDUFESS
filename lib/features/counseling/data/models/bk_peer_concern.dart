class BkPeerConcern {
  const BkPeerConcern({
    required this.id,
    required this.targetDisplay,
    required this.reason,
    this.details,
    required this.status,
    required this.createdAt,
    this.handledAt,
    this.closedAt,
    this.withdrawnAt,
    this.detailsPreview,
    this.reporterResponse,
    this.resolutionNote,
  });

  factory BkPeerConcern.fromMap(Map<String, dynamic> m) {
    return BkPeerConcern(
      id: m['concern_id'] as String? ?? m['id'] as String,
      targetDisplay: m['target_display'] as String,
      reason: m['reason'] as String,
      details: m['details'] as String?,
      status: m['status'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      handledAt: m['handled_at'] != null ? DateTime.parse(m['handled_at'] as String) : null,
      closedAt: m['closed_at'] != null ? DateTime.parse(m['closed_at'] as String) : null,
      withdrawnAt: m['withdrawn_at'] != null ? DateTime.parse(m['withdrawn_at'] as String) : null,
      detailsPreview: m['details_preview'] as String?,
      reporterResponse: m['reporter_response'] as String?,
      // resolution_note exists only in counselor projections; the student
      // projection never returns this column, so it stays null there.
      resolutionNote: m['resolution_note'] as String?,
    );
  }

  final String id;
  final String targetDisplay;
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;
  final DateTime? handledAt;
  final DateTime? closedAt;
  final DateTime? withdrawnAt;
  final String? detailsPreview;
  final String? reporterResponse;
  final String? resolutionNote;

  String get reasonLabel {
    switch (reason) {
      case 'emotional':
        return 'Kondisi Emosional';
      case 'social':
        return 'Masalah Sosial';
      case 'academic':
        return 'Kesulitan Akademik';
      case 'family':
        return 'Masalah Keluarga';
      case 'bullying':
        return 'Perundungan';
      case 'safety_concern':
        return 'Kekhawatiran Keselamatan';
      case 'other':
        return 'Lainnya';
      default:
        return reason;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu penanganan';
      case 'reviewing':
        return 'Sedang ditinjau';
      case 'resolved':
        return 'Selesai ditindaklanjuti';
      case 'dismissed':
        return 'Ditutup tanpa tindak lanjut';
      case 'withdrawn':
        return 'Ditarik';
      default:
        return status;
    }
  }
}

class PeerStudent {
  const PeerStudent({required this.studentRef, required this.displayPseudonym});
  factory PeerStudent.fromMap(Map<String, dynamic> m) {
    return PeerStudent(
      studentRef: m['student_ref'] as String,
      displayPseudonym: m['display_pseudonym'] as String,
    );
  }
  final String studentRef;
  final String displayPseudonym;
}
