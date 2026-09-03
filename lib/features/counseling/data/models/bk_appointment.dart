class CounselorSlot {
  const CounselorSlot({
    required this.availabilityId,
    required this.availableDate,
    required this.startTime,
    required this.endTime,
    required this.counselorDisplay,
  });

  factory CounselorSlot.fromMap(Map<String, dynamic> m) {
    return CounselorSlot(
      availabilityId: m['availability_id'] as String,
      availableDate: DateTime.parse(m['available_date'] as String),
      startTime: m['start_time'] as String,
      endTime: m['end_time'] as String,
      counselorDisplay: m['counselor_display'] as String,
    );
  }

  final String availabilityId;
  final DateTime availableDate;
  final String startTime; // "09:00:00"
  final String endTime;
  final String counselorDisplay;

  String get dateLabel => '${availableDate.day}/${availableDate.month}/${availableDate.year}';
  String get timeLabel => '$startTime - $endTime';
}

class BkAppointment {
  const BkAppointment({
    required this.appointmentId,
    required this.status,
    required this.requestedStartAt,
    required this.requestedEndAt,
    this.scheduledStartAt,
    this.scheduledEndAt,
    this.studentNote,
    this.counselorNote,
    this.counselorDisplay,
    this.studentAlias,
    required this.createdAt,
    this.cancelledAt,
    this.completedAt,
  });

  factory BkAppointment.fromStudentMap(Map<String, dynamic> m) {
    return BkAppointment(
      appointmentId: m['appointment_id'] as String,
      status: m['status'] as String,
      requestedStartAt: DateTime.parse(m['requested_start_at'] as String),
      requestedEndAt: DateTime.parse(m['requested_end_at'] as String),
      scheduledStartAt: m['scheduled_start_at'] != null ? DateTime.parse(m['scheduled_start_at'] as String) : null,
      scheduledEndAt: m['scheduled_end_at'] != null ? DateTime.parse(m['scheduled_end_at'] as String) : null,
      studentNote: m['student_note'] as String?,
      counselorDisplay: m['counselor_display'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      cancelledAt: m['cancelled_at'] != null ? DateTime.parse(m['cancelled_at'] as String) : null,
      completedAt: m['completed_at'] != null ? DateTime.parse(m['completed_at'] as String) : null,
    );
  }

  factory BkAppointment.fromCounselorMap(Map<String, dynamic> m) {
    return BkAppointment(
      appointmentId: m['appointment_id'] as String,
      status: m['status'] as String,
      requestedStartAt: DateTime.parse(m['requested_start_at'] as String),
      requestedEndAt: DateTime.parse(m['requested_end_at'] as String),
      scheduledStartAt: m['scheduled_start_at'] != null ? DateTime.parse(m['scheduled_start_at'] as String) : null,
      scheduledEndAt: m['scheduled_end_at'] != null ? DateTime.parse(m['scheduled_end_at'] as String) : null,
      studentNote: m['student_note'] as String?,
      counselorNote: m['counselor_note'] as String?,
      studentAlias: m['student_alias'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      cancelledAt: m['cancelled_at'] != null ? DateTime.parse(m['cancelled_at'] as String) : null,
      completedAt: m['completed_at'] != null ? DateTime.parse(m['completed_at'] as String) : null,
    );
  }

  final String appointmentId;
  final String status;
  final DateTime requestedStartAt;
  final DateTime requestedEndAt;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final String? studentNote;
  final String? counselorNote;
  final String? counselorDisplay;
  final String? studentAlias;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  bool get isCompleted => status == 'completed';
}

class CounselorAvailability {
  const CounselorAvailability({
    required this.id,
    required this.counselorId,
    required this.availableDate,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  factory CounselorAvailability.fromMap(Map<String, dynamic> m) {
    return CounselorAvailability(
      id: m['id'] as String,
      counselorId: m['counselor_id'] as String,
      availableDate: DateTime.parse(m['available_date'] as String),
      startTime: m['start_time'] as String,
      endTime: m['end_time'] as String,
      isActive: m['is_active'] as bool,
    );
  }

  final String id;
  final String counselorId;
  final DateTime availableDate;
  final String startTime;
  final String endTime;
  final bool isActive;
}
