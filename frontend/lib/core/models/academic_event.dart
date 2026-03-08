class AcademicEvent {
  const AcademicEvent({
    required this.id,
    required this.sessionId,
    required this.termId,
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    required this.allDay,
    required this.hideClassesDuringEvent,
  });

  final String id;
  final String sessionId;
  final String termId;
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool allDay;
  final bool hideClassesDuringEvent;

  AcademicEvent copyWith({
    String? id,
    String? sessionId,
    String? termId,
    String? title,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? allDay,
    bool? hideClassesDuringEvent,
  }) {
    return AcademicEvent(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      termId: termId ?? this.termId,
      title: title ?? this.title,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      allDay: allDay ?? this.allDay,
      hideClassesDuringEvent:
          hideClassesDuringEvent ?? this.hideClassesDuringEvent,
    );
  }
}

