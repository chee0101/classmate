import 'package:flutter/foundation.dart';

import '../models/course.dart';

final ValueNotifier<List<Course>> mockCoursesNotifier =
    ValueNotifier<List<Course>>([]);

List<Course> coursesForSession(String sessionId) {
  return mockCoursesNotifier.value
      .where((c) => c.sessionId == sessionId)
      .toList(growable: false);
}

bool hasCoursesForSession(String sessionId) {
  return mockCoursesNotifier.value.any((c) => c.sessionId == sessionId);
}

bool courseCodeExistsInSession({
  required String sessionId,
  required String courseCode,
}) {
  final normalized = courseCode.trim().toUpperCase();
  return mockCoursesNotifier.value.any(
    (c) => c.sessionId == sessionId && c.courseCode.toUpperCase() == normalized,
  );
}

bool courseCodeExistsInSessionAndTerm({
  required String sessionId,
  required String termId,
  required String courseCode,
}) {
  final normalized = courseCode.trim().toUpperCase();
  return mockCoursesNotifier.value.any(
    (c) => c.sessionId == sessionId && 
           c.termId == termId && 
           c.courseCode.toUpperCase() == normalized,
  );
}

void addCourse({
  required String sessionId,
  required String termId,
  required String courseCode,
  required String courseColor,
}) {
  if (courseCodeExistsInSessionAndTerm(
    sessionId: sessionId,
    termId: termId,
    courseCode: courseCode,
  )) {
    return;
  }

  final next = List<Course>.from(mockCoursesNotifier.value)
    ..add(
      Course(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sessionId: sessionId,
        termId: termId,
        courseCode: courseCode.trim().toUpperCase(),
        courseColor: courseColor,
      ),
    );
  mockCoursesNotifier.value = next;
}

