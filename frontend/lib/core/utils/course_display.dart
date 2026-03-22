import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/task.dart';
import '../models/timetable_entry.dart';

Color _parseCourseHex(String colorHex) {
  final parsed = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
  return Color(parsed ?? 0xFF6C4DD9);
}

/// Resolves the label from the canonical [Course] row when [courseId] is set.
String displayCourseCodeForTask(Task task, List<Course> courses) {
  final id = task.courseId?.trim();
  if (id != null && id.isNotEmpty) {
    for (final c in courses) {
      if (c.id == id) return c.courseCode;
    }
  }
  return task.courseCode;
}

Color displayCourseColorForTask(Task task, List<Course> courses) {
  final id = task.courseId?.trim();
  if (id != null && id.isNotEmpty) {
    for (final c in courses) {
      if (c.id == id) {
        return _parseCourseHex(c.courseColor);
      }
    }
  }
  return task.courseColor;
}

String displayCourseCodeForTimetableData({
  required String? courseId,
  required String storedCourseCode,
  required List<Course> courses,
}) {
  final id = courseId?.trim();
  if (id != null && id.isNotEmpty) {
    for (final c in courses) {
      if (c.id == id) return c.courseCode;
    }
  }
  return storedCourseCode;
}

String displayCourseCodeForTimetableEntry(
  TimetableEntry entry,
  List<Course> courses,
) {
  return displayCourseCodeForTimetableData(
    courseId: entry.courseId,
    storedCourseCode: entry.courseCode,
    courses: courses,
  );
}

Color displayCourseColorForTimetableData({
  required String? courseId,
  required List<Course> courses,
}) {
  final id = courseId?.trim();
  if (id != null && id.isNotEmpty) {
    for (final c in courses) {
      if (c.id == id) {
        return _parseCourseHex(c.courseColor);
      }
    }
  }
  return const Color(0xFF6C4DD9);
}

Color displayCourseColorForTimetableEntry(
  TimetableEntry entry,
  List<Course> courses,
) {
  return displayCourseColorForTimetableData(
    courseId: entry.courseId,
    courses: courses,
  );
}
