import 'package:flutter/material.dart';

enum TaskStatus {
  ongoing,
  overdue,
  completed,
}

class Task {
  final String id;
  final String? courseId;
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
    String? description,
    DateTime? dueDateTime,
    TaskStatus? status,
    String? parentTaskId,
  }) {
    return Task(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
      courseColor: courseColor ?? this.courseColor,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDateTime: dueDateTime ?? this.dueDateTime,
      status: status ?? this.status,
      parentTaskId: parentTaskId ?? this.parentTaskId,
    );
  }
}

