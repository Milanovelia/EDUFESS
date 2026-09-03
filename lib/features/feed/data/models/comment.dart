/// Privacy-safe comment for discussion.
///
/// Uses [displayAuthor] resolved server-side:
/// - public → pseudonym
/// - pseudonymous → anonymous_alias
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.content,
    required this.isPseudonymous,
    required this.displayAuthor,
    required this.isBestAnswer,
    required this.createdAt,
    required this.updatedAt,
    this.isOwn = false,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      parentId: map['parent_id'] as String?,
      content: map['content'] as String,
      isPseudonymous: map['is_pseudonymous'] as bool,
      displayAuthor: map['display_author'] as String,
      isBestAnswer: map['is_best_answer'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isOwn: map['is_own'] as bool? ?? false,
    );
  }

  final String id;
  final String postId;
  final String? parentId;
  final String content;
  final bool isPseudonymous;
  final String displayAuthor;
  final bool isBestAnswer;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOwn;

  bool get isReply => parentId != null;
}
