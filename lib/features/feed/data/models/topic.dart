/// Topic scoped to a subject.
class Topic {
  const Topic({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String subjectId;
  final String name;
  final String slug;
  final DateTime createdAt;
}
