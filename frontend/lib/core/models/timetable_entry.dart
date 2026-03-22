import 'class_type.dart';

class TimetableSlot {
  const TimetableSlot({
    required this.classSlotId,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.mode,
    required this.classType,
    this.venue,
  });

  final String classSlotId;
  final String day;
  final String startTime;
  final String endTime;
  final String mode;
  final ClassType classType;
  final String? venue;

  TimetableSlot copyWith({
    String? classSlotId,
    String? day,
    String? startTime,
    String? endTime,
    String? mode,
    ClassType? classType,
    String? venue,
  }) {
    return TimetableSlot(
      classSlotId: classSlotId ?? this.classSlotId,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      mode: mode ?? this.mode,
      classType: classType ?? this.classType,
      venue: venue ?? this.venue,
    );
  }
}

/// One row per course timetable; [id] is the Firestore `courses/{id}` document id.
class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.sessionId,
    required this.termId,
    required this.courseCode,
    required this.slots,
  });

  final String id;
  final String sessionId;
  final String termId;
  final String courseCode;
  final List<TimetableSlot> slots;

  TimetableEntry copyWith({
    String? id,
    String? sessionId,
    String? termId,
    String? courseCode,
    List<TimetableSlot>? slots,
  }) {
    return TimetableEntry(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      termId: termId ?? this.termId,
      courseCode: courseCode ?? this.courseCode,
      slots: slots ?? this.slots,
    );
  }
}
