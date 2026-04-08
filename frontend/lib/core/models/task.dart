import 'package:flutter/material.dart';

enum TaskStatus {
  ongoing,
  overdue,
  completed,
}

class Task {
  static const Object _unsetDescription = Object();

  final String id;

  /// Firestore `users/.../courses/{id}` — canonical link for course-linked tasks.
  final String? courseId;

  /// In-memory label/color, preferably resolved from [Course] via [courseId].
  /// Firestore task docs store only [courseId] for course data once migrated.
  final String courseCode;
  final Color courseColor;
  final String title;
  final String? description;
  final DateTime dueDateTime;
  final TaskStatus status;
  final String? parentTaskId;

  const Task({
    required this.id,
    this.courseId,
    required this.courseCode,
    required this.courseColor,
    required this.title,
    this.description,
    required this.dueDateTime,
    required this.status,
    this.parentTaskId,
  });

  Task copyWith({
    String? id,
    String? courseId,
    String? courseCode,
    Color? courseColor,
    String? title,
    Object? description = _unsetDescription,
    DateTime? dueDateTime,
    TaskStatus? status,
    String? parentTaskId,
  }) {
    final resolvedDescription = identical(description, _unsetDescription)
        ? this.description
        : description as String?;
    return Task(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
      courseColor: courseColor ?? this.courseColor,
      title: title ?? this.title,
      description: resolvedDescription,
      dueDateTime: dueDateTime ?? this.dueDateTime,
      status: status ?? this.status,
      parentTaskId: parentTaskId ?? this.parentTaskId,
    );
  }
}

