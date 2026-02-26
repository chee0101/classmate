import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/mock/mock_tasks.dart';
import '../../core/models/task.dart';
import '../../core/widgets/task/task_card.dart';
import '../../core/widgets/task/task_course_filter.dart';
import '../../core/widgets/task/task_status_tabs.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  TaskStatus _selectedStatus = TaskStatus.ongoing;

  late List<Task> _tasks;
  String? _selectedCourseCode; // null = All courses

  @override
  void initState() {
    super.initState();
    // Only show top-level tasks in the list (subtasks are shown in detail view).
    _tasks = mockTopLevelTasks();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Build distinct course codes for the filter.
    final courseCodes = _tasks.map((t) => t.courseCode).toSet().toList()
      ..sort();

    final tasks = _tasks.where((t) {
      final matchesStatus = t.status == _selectedStatus;
      final matchesCourse =
          _selectedCourseCode == null || t.courseCode == _selectedCourseCode;
      return matchesStatus && matchesCourse;
    }).toList()
      ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: TaskStatusTabs(
              selected: _selectedStatus,
              onChanged: (status) {
                setState(() => _selectedStatus = status);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TaskCourseFilter(
              textTheme: textTheme,
              courseCodes: courseCodes,
              selectedCourseCode: _selectedCourseCode,
              onChanged: (code) {
                setState(() => _selectedCourseCode = code);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.zero,
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks found. Looks like you\'re all caught up!',
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.lg,
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                      ),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final nextSubtaskTitle = _getNextSubtaskTitle(task.id);
                        return TaskCard(
                          task: task,
                          onMarkDone: () => _markTaskAsCompleted(task),
                          onTap: () => _navigateToTaskDetail(task),
                          nextSubtaskTitle: nextSubtaskTitle,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _markTaskAsCompleted(Task task) {
    if (task.status == TaskStatus.completed) return;

    setState(() {
      _tasks = _tasks
          .map(
            (t) =>
                t.id == task.id ? t.copyWith(status: TaskStatus.completed) : t,
          )
          .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task marked as completed'),
      ),
    );
  }

  void _navigateToTaskDetail(Task task) {
    Navigator.pushNamed(
      context,
      AppRoutes.taskDetail,
      arguments: task,
    );
  }

  /// Returns the title of the nearest-due (and not yet completed) subtask,
  /// or null if there is no such subtask.
  String? _getNextSubtaskTitle(String parentTaskId) {
    final subtasks = mockSubtasksFor(parentTaskId);
    if (subtasks.isEmpty) return null;

    final remaining = subtasks
        .where((t) => t.status != TaskStatus.completed)
        .toList()
      ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));

    if (remaining.isEmpty) return null;
    return remaining.first.title;
  }
}