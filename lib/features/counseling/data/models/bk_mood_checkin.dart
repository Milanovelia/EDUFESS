class BkMoodCheckin {
  const BkMoodCheckin({
    required this.id,
    required this.moodLevel,
    this.note,
    required this.checkedInAt,
  });

  factory BkMoodCheckin.fromMap(Map<String, dynamic> m) {
    return BkMoodCheckin(
      id: m['checkin_id'] as String? ?? m['id'] as String,
      moodLevel: (m['mood_level'] as int),
      note: m['note'] as String?,
      checkedInAt: DateTime.parse(m['checked_in_at'] as String),
    );
  }

  final String id;
  final int moodLevel; // 1..5
  final String? note;
  final DateTime checkedInAt;

  String get label {
    switch (moodLevel) {
      case 1:
        return 'Sangat Buruk';
      case 2:
        return 'Buruk';
      case 3:
        return 'Biasa';
      case 4:
        return 'Baik';
      case 5:
        return 'Sangat Baik';
      default:
        return '$moodLevel';
    }
  }

  String get emoji {
    switch (moodLevel) {
      case 1:
        return '😞';
      case 2:
        return '🙁';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '•';
    }
  }
}
