import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/task.dart';
import '../models/timetable_entry.dart';
import 'course_resolver.dart';

Color _parseCourseHex(String colorHex) {
  final parsed = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
  return Color(parsed ?? 0xFF6C4DD9);
}

/// Resolves the label from the canonical [Course] row when [courseId] is set.
String displayCourseCodeForTask(Task task, List<Course> courses) {
  final c = lookupCourseById(task.courseId, courses);
  if (c != null) return c.courseCode;
  return task.courseCode;
}

Color displayCourseColorForTask(Task task, List<Course> courses) {
  final c = lookupCourseById(task.courseId, courses);
  if (c != null) return _parseCourseHex(c.courseColor);
  return task.courseColor;
}

/// [courseId] is the Firestore `courses/{id}` document id.
String displayCourseCodeForTimetableData({
  required String? courseId,
  required List<Course> courses,
}) {
  final c = lookupCourseById(courseId, courses);
  return c?.courseCode ?? '';
}

String displayCourseCodeForTimetableEntry(
  TimetableEntry entry,
  List<Course> courses,
) {
  final fromCourse = displayCourseCodeForTimetableData(
    courseId: entry.id,
    courses: courses,
  );
  if (fromCourse.isNotEmpty) return fromCourse;
  return entry.courseCode;
}

Color displayCourseColorForTimetableData({
  required String? courseId,
  required List<Course> courses,
}) {
  final c = lookupCourseById(courseId, courses);
  if (c != null) return _parseCourseHex(c.courseColor);
  return const Color(0xFF6C4DD9);
}

Color displayCourseColorForTimetableEntry(
  TimetableEntry entry,
  List<Course> courses,
) {
  return displayCourseColorForTimetableData(
    courseId: entry.id,
    courses: courses,
  );
}
