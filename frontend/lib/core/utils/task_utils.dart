import '../models/task.dart';

/// Utility functions for task operations.
class TaskUtils {
  static bool isOverdue(Task task, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    return task.status != TaskStatus.completed &&
        task.dueDateTime.isBefore(effectiveNow);
  }

  static TaskStatus effectiveStatus(Task task, {DateTime? now}) {
    if (task.status == TaskStatus.completed) return TaskStatus.completed;
    return isOverdue(task, now: now) ? TaskStatus.overdue : TaskStatus.ongoing;
  }

  /// Filters and sorts upcoming tasks (tasks with due date after now).
  static List<Task> getUpcomingTasks(List<Task> allTasks) {
    final now = DateTime.now();
    return allTasks
        .where((t) => t.dueDateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));
  }
}
