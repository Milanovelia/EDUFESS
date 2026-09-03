/// Privacy-safe post for feed/detail.
///
/// Uses [displayAuthor] which is already resolved server-side:
/// - public post → real pseudonym
/// - pseudonymous post → anonymous alias (e.g. Siswa Anonim #A1B2)
/// Never exposes email or raw author mapping to the client.
class Post {
  const Post({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.isPseudonymous,
    required this.displayAuthor,
    required this.subjectId,
    required this.subjectName,
    required this.subjectSlug,
    this.topicId,
    this.topicName,
    this.topicSlug,
    required this.createdAt,
    required this.updatedAt,
    this.helpfulCount = 0,
    this.currentUserHelpful = false,
    this.currentUserBookmarked = false,
    this.commentCount = 0,
    this.hasBestAnswer = false,
    this.authorId,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      isPseudonymous: map['is_pseudonymous'] as bool,
      displayAuthor: map['display_author'] as String,
      subjectId: map['subject_id'] as String,
      subjectName: map['subject_name'] as String,
      subjectSlug: map['subject_slug'] as String,
      topicId: map['topic_id'] as String?,
      topicName: map['topic_name'] as String?,
      topicSlug: map['topic_slug'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      helpfulCount: (map['helpful_count'] as int?) ?? 0,
      currentUserHelpful: map['current_user_helpful'] as bool? ?? false,
      currentUserBookmarked: map['current_user_bookmarked'] as bool? ?? false,
      commentCount: (map['comment_count'] as int?) ?? 0,
      hasBestAnswer: map['has_best_answer'] as bool? ?? false,
      authorId: map['author_id'] as String?,
    );
  }

  final String id;
  final String type;
  final String title;
  final String content;
  final bool isPseudonymous;
  final String displayAuthor;
  final String subjectId;
  final String subjectName;
  final String subjectSlug;
  final String? topicId;
  final String? topicName;
  final String? topicSlug;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int helpfulCount;
  final bool currentUserHelpful;
  final bool currentUserBookmarked;
  final int commentCount;
  final bool hasBestAnswer;
  final String? authorId;

  /// Short preview for feed cards (max 120 chars).
  String get preview {
    if (content.length <= 120) return content;
    return '${content.substring(0, 120)}…';
  }
}

/// Supported post types — matches DB CHECK constraint.
abstract final class PostType {
  static const String note = 'note';
  static const String question = 'question';
  static const String summary = 'summary';
  static const String tip = 'tip';
  static const String request = 'request';

  static const List<String> all = [note, question, summary, tip, request];

  static const Map<String, String> labels = {
    note: 'Catatan',
    question: 'Pertanyaan',
    summary: 'Rangkuman',
    tip: 'Tips',
    request: 'Permintaan',
  };
}
