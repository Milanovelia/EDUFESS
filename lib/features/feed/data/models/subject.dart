/// Subject (mata pelajaran) master data.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;
}
