import '../models/course.dart';

/// Resolves a [Course] from the list by Firestore document id.
Course? lookupCourseById(String? courseId, List<Course> courses) {
  final id = courseId?.trim();
  if (id == null || id.isEmpty) return null;
  for (final c in courses) {
    if (c.id == id) return c;
  }
  return null;
}
