class BkConversation {
  const BkConversation({
    required this.id,
    required this.studentId,
    this.counselorId,
    required this.studentAlias,
    required this.status,
    this.identityRevealedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BkConversation.fromMap(Map<String, dynamic> m) {
    return BkConversation(
      id: m['id'] as String,
      studentId: m['student_id'] as String,
      counselorId: m['counselor_id'] as String?,
      studentAlias: m['student_alias'] as String,
      status: m['status'] as String,
      identityRevealedAt: m['identity_revealed_at'] != null ? DateTime.parse(m['identity_revealed_at'] as String) : null,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  // For queue/student RPCs which use conversation_id alias
  factory BkConversation.fromQueueMap(Map<String, dynamic> m) {
    return BkConversation(
      id: (m['conversation_id'] ?? m['id']) as String,
      studentId: (m['student_id'] ?? '') as String, // may be empty for counselor queue (alias only) — but we keep alias
      counselorId: m['counselor_id'] as String?,
      studentAlias: m['student_alias'] as String,
      status: m['status'] as String,
      identityRevealedAt: null,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: m['updated_at'] != null ? DateTime.parse(m['updated_at'] as String) : DateTime.parse(m['created_at'] as String),
    );
  }

  final String id;
  final String studentId;
  final String? counselorId;
  final String studentAlias;
  final String status;
  final DateTime? identityRevealedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BkMessage {
  const BkMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory BkMessage.fromMap(Map<String, dynamic> m) {
    return BkMessage(
      id: m['id'] as String,
      conversationId: m['conversation_id'] as String,
      senderId: m['sender_id'] as String,
      content: m['content'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
}
