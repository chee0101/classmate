import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/task.dart';

/// Temporary in-memory mock data for the Task screen.
///
/// This lets you build and fine-tune the UI before wiring up Firebase
/// or a backend. Later you can replace this with real data providers.
final ValueNotifier<List<Task>> mockTasksNotifier = ValueNotifier<List<Task>>([
  // Top-level tasks
  Task(
    id: 't1',
    courseCode: 'CAT401',
    courseColor: const Color(0xFFFFA25B),
    title: 'Assignment 1',
    description: 'First assignment on probability.',
    dueDateTime: DateTime.now().add(const Duration(days: 1, hours: 5)),
    status: TaskStatus.ongoing,
  ),
  Task(
    id: 't2',
    courseCode: 'CST435',
    courseColor: const Color(0xFF4C6FFF),
    title: 'Project 2',
    description: 'Work on final project proposal and related tasks.',
    dueDateTime: DateTime.now().add(const Duration(days: 3)),
    status: TaskStatus.ongoing,
  ),
  Task(
    id: 't3',
    courseCode: 'CAT401',
    courseColor: const Color(0xFFFFA25B),
    title: 'Quiz Preparation',
    description: 'Study chapters 3–4.',
    dueDateTime: DateTime.now().subtract(const Duration(hours: 2)),
    status: TaskStatus.overdue,
  ),
  Task(
    id: 't4',
    courseCode: 'CSE441',
    courseColor: const Color(0xFF54C6A8),
    title: 'Lab Report',
    description: 'Submit lab report for week 5.',
    dueDateTime: DateTime.now().subtract(const Duration(days: 1)),
    status: TaskStatus.completed,
  ),

  // Subtasks for Project 2 (t2)
  Task(
    id: 'st1',
    parentTaskId: 't2',
    courseCode: 'CST435',
    courseColor: const Color(0xFF4C6FFF),
    title: 'Draft Proposal',
    description: 'Create initial draft of project proposal.',
    dueDateTime: DateTime.now().add(const Duration(days: 2)),
    status: TaskStatus.overdue,
  ),
  Task(
    id: 'st2',
    parentTaskId: 't2',
    courseCode: 'CST435',
    courseColor: const Color(0xFF4C6FFF),
    title: 'Review Literature',
    description: 'Review relevant papers and articles.',
    dueDateTime: DateTime.now().add(const Duration(days: 3)),
    status: TaskStatus.ongoing,
  ),
  Task(
    id: 'st3',
    parentTaskId: 't2',
    courseCode: 'CST435',
    courseColor: const Color(0xFF4C6FFF),
    title: 'Finalize Proposal',
    description: 'Polish and submit final proposal.',
    dueDateTime: DateTime.now().add(const Duration(days: 4)),
    status: TaskStatus.completed,
  ),
]);

List<Task> mockTopLevelTasks() =>
    mockTasksNotifier.value.where((t) => t.parentTaskId == null).toList();

List<Task> mockSubtasksFor(String parentTaskId) =>
    mockTasksNotifier.value.where((t) => t.parentTaskId == parentTaskId).toList();
