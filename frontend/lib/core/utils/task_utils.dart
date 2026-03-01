import '../models/task.dart';

/// Utility functions for task operations.
class TaskUtils {
  /// Filters and sorts upcoming tasks (tasks with due date after now).
  static List<Task> getUpcomingTasks(List<Task> allTasks) {
    final now = DateTime.now();
    return allTasks
        .where((t) => t.dueDateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));
  }
}
