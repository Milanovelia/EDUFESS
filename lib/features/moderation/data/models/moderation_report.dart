/// Report reasons — matches DB CHECK constraint.
abstract final class ReportReason {
  static const String spam = 'spam';
  static const String harassment = 'harassment';
  static const String hate = 'hate';
  static const String sexual = 'sexual';
  static const String violence = 'violence';
  static const String misinformation = 'misinformation';
  static const String privacy = 'privacy';
  static const String other = 'other';

  static const List<String> all = [spam, harassment, hate, sexual, violence, misinformation, privacy, other];

  static const Map<String, String> labels = {
    spam: 'Spam',
    harassment: 'Pelecehan',
    hate: 'Ujaran kebencian',
    sexual: 'Konten seksual',
    violence: 'Kekerasan',
    misinformation: 'Informasi menyesatkan',
    privacy: 'Privasi',
    other: 'Lainnya',
  };
}

/// Moderation report for queue — reporter identity NOT exposed (privacy).
class ModerationReport {
  const ModerationReport({
    required this.reportId,
    required this.targetType,
    required this.reason,
    this.details,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.postId,
    this.commentId,
    this.targetTitle,
    this.targetContent,
    required this.displayAuthor,
    this.subjectName,
    this.topicName,
  });

  factory ModerationReport.fromMap(Map<String, dynamic> m) {
    return ModerationReport(
      reportId: m['report_id'] as String,
      targetType: m['target_type'] as String,
      reason: m['reason'] as String,
      details: m['details'] as String?,
      status: m['status'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      reviewedAt: m['reviewed_at'] != null ? DateTime.parse(m['reviewed_at'] as String) : null,
      reviewedBy: m['reviewed_by'] as String?,
      postId: m['post_id'] as String?,
      commentId: m['comment_id'] as String?,
      targetTitle: m['target_title'] as String?,
      targetContent: m['target_content'] as String?,
      displayAuthor: m['display_author'] as String? ?? 'Anonim',
      subjectName: m['subject_name'] as String?,
      topicName: m['topic_name'] as String?,
    );
  }

  final String reportId;
  final String targetType; // post|comment
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? postId;
  final String? commentId;
  final String? targetTitle;
  final String? targetContent;
  final String displayAuthor;
  final String? subjectName;
  final String? topicName;

  bool get isPost => targetType == 'post';
}
