import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/task.dart';
import '../../core/services/task_store.dart';
import '../../core/widgets/task/task_card.dart';
import '../../core/widgets/task/subtask_card.dart';
import '../../core/widgets/task/task_edit_bottom_sheet.dart';

/// Task detail screen showing full task info, subtasks, and actions.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  final Task task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;
  late List<Task> _subtasks;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _subtasks = const <Task>[];
    _syncFromStore(notify: false);
    tasksNotifier.addListener(_onTasksChanged);
  }

  @override
  void dispose() {
    tasksNotifier.removeListener(_onTasksChanged);
    super.dispose();
  }

  void _onTasksChanged() {
    _syncFromStore();
  }

  void _syncFromStore({bool notify = true}) {
    final allTasks = tasksNotifier.value;
    final matchedTask = allTasks.where((task) => task.id == _task.id);
    if (matchedTask.isNotEmpty) {
      _task = matchedTask.first;
    }

    _subtasks = allTasks
        .where((task) => task.parentTaskId == _task.id)
        .toList(growable: false);
    _sortSubtasks();
    if (notify && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final allSubtasksCompleted = _subtasks.isEmpty ||
        _subtasks.every((t) => t.status == TaskStatus.completed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: () {
                setState(() => _isEditing = false);
              },
              child: const Text('Done'),
            )
          else
            PopupMenuButton<String>(
              color: Colors.white,
              onSelected: (value) {
                if (value == 'edit') {
                  setState(() => _isEditing = true);
                } else if (value == 'delete') {
                  _handleDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main task card with edit button
            _buildMainTaskCard(textTheme, colorScheme),
            const SizedBox(height: AppSpacing.lg),

            // Sub Tasks section
            _buildSubtasksSection(textTheme, colorScheme),
            const SizedBox(height: AppSpacing.xl),

            // Mark as completed button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _task.status == TaskStatus.completed ||
                        !allSubtasksCompleted
                    ? null
                    : () async => _handleMarkAsCompleted(),
                child: const Text('Mark as completed'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTaskCard(TextTheme textTheme, ColorScheme colorScheme) {
    return TaskCard(
      task: _task,
      onMarkDone: () {}, // Disabled in detail view
      showMarkDone: false,
      footer: _isEditing
          ? SizedBox(
              height: 44,
              child: Center(
                child: TextButton(
                  onPressed: () async => _handleEdit(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Edit'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSubtasksSection(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sub Tasks',
              style: textTheme.headlineMedium,
            ),
            if (_subtasks.isNotEmpty)
              TextButton(
                onPressed: () async => _handleMarkAllSubtasksCompleted(),
                child: const Text('Mark all as completed'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_subtasks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'No subtasks yet. Add one to break down this task.',
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._subtasks.map(
            (subtask) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SubtaskCard(
                subtask: subtask,
                onMarkDone: () async => _handleSubtaskMarkDone(subtask),
                onEdit: () async => _handleEditSubtask(subtask),
                onDelete: () => _handleDeleteSubtask(subtask),
                isEditing: _isEditing,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _handleAddSubtask,
            icon: const Icon(Icons.add),
            label: const Text('Add sub task'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleEdit() {
    TaskEditBottomSheet.show(
      context,
      task: _task,
      sheetTitle: 'Edit Task',
    ).then((updatedTask) async {
      if (updatedTask == null) return;
      await updateTask(updatedTask);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated')),
      );
    });
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteTask(_task.id, deleteSubtasks: true);
              if (!mounted) return;
              Navigator.of(this.context).pop(); // Go back to task list
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Task deleted')),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMarkAsCompleted() async {
    await updateTask(_task.copyWith(status: TaskStatus.completed));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task marked as completed')),
    );
  }

  void _handleAddSubtask() {
    // Create a draft subtask seeded from the parent task.
    final draftSubtask = Task(
      id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
      parentTaskId: _task.id,
      courseId: _task.courseId,
      courseCode: _task.courseCode,
      courseColor: _task.courseColor,
      title: '',
      description: null,
      dueDateTime: _task.dueDateTime,
      status: TaskStatus.ongoing,
    );

    TaskEditBottomSheet.show(
      context,
      task: draftSubtask,
      sheetTitle: 'Add Subtask',
      isSubtask: true,
      parentDueDateTime: _task.dueDateTime,
    ).then((createdSubtask) async {
      if (createdSubtask == null) return;
      await addTask(createdSubtask);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subtask added')),
      );
    });
  }

  Future<void> _handleSubtaskMarkDone(Task subtask) async {
    await updateTask(subtask.copyWith(status: TaskStatus.completed));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subtask marked as completed')),
    );
  }

  void _handleDeleteSubtask(Task subtask) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subtask'),
        content: Text('Delete "${subtask.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteTask(subtask.id);
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Subtask deleted')),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditSubtask(Task subtask) async {
    TaskEditBottomSheet.show(
      context,
      task: subtask,
      sheetTitle: 'Edit Subtask',
      isSubtask: true,
      parentDueDateTime: _task.dueDateTime,
    ).then((updatedSubtask) async {
      if (updatedSubtask == null) return;
      await updateTask(updatedSubtask);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subtask updated')),
      );
    });
  }

  Future<void> _handleMarkAllSubtasksCompleted() async {
    final pending = _subtasks
        .where((task) => task.status != TaskStatus.completed)
        .toList(growable: false);
    await Future.wait(
      pending.map((task) => updateTask(task.copyWith(status: TaskStatus.completed))),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All subtasks marked as completed')),
    );
  }

  /// Keeps subtasks ordered with non-completed first, then completed,
  /// and within each group by nearest due date.
  void _sortSubtasks() {
    _subtasks.sort((a, b) {
      final aCompleted = a.status == TaskStatus.completed ? 1 : 0;
      final bCompleted = b.status == TaskStatus.completed ? 1 : 0;
      if (aCompleted != bCompleted) {
        return aCompleted.compareTo(bCompleted); // 0 before 1
      }
      return a.dueDateTime.compareTo(b.dueDateTime);
    });
  }
}

