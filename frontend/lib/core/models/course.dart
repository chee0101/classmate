class Course {
  final String id;
  final String sessionId;
  final String courseCode;
  final String courseColor;

  const Course({
    required this.id,
    required this.sessionId,
    required this.courseCode,
    required this.courseColor,
  });

  Course copyWith({
    String? id,
    String? sessionId,
    String? courseCode,
    String? courseColor,
  }) {
    return Course(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      courseCode: courseCode ?? this.courseCode,
      courseColor: courseColor ?? this.courseColor,
    );
  }
}

