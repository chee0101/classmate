class Course {
  final String id;
  final String sessionId;
  final String termId;
  final String courseCode;
  final String courseColor;

  const Course({
    required this.id,
    required this.sessionId,
    required this.termId,
    required this.courseCode,
    required this.courseColor,
  });

  Course copyWith({
    String? id,
    String? sessionId,
    String? termId,
    String? courseCode,
    String? courseColor,
  }) {
    return Course(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      termId: termId ?? this.termId,
      courseCode: courseCode ?? this.courseCode,
      courseColor: courseColor ?? this.courseColor,
    );
  }
}

