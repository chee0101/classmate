import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/task.dart';
import '../../core/mock/mock_tasks.dart';
import '../../core/widgets/task/task_card.dart';
import '../../core/widgets/task/subtask_card.dart';
import '../../core/widgets/task/task_edit_bottom_sheet.dart';

/// Task detail screen showing full task info, subtasks, and actions.
///
/// TODO: Replace mock subtasks with real data from backend.
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
    // TODO: Load subtasks from backend based on _task.id
    _subtasks = mockSubtasksFor(_task.id);

    // If the main task is already completed (e.g. user marked it as done
    // from the task list screen), reflect that by marking all subtasks
    // as completed as well.
    if (_task.status == TaskStatus.completed) {
      _subtasks = _subtasks
          .map(
            (t) => t.copyWith(status: TaskStatus.completed),
          )
          .toList();
    }

    _sortSubtasks();
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
                  child: Text('Edit task'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete task'),
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
                    : _handleMarkAsCompleted,
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
                  onPressed: _handleEdit,
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
                onPressed: _handleMarkAllSubtasksCompleted,
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
                onMarkDone: () => _handleSubtaskMarkDone(subtask),
                onEdit: () => _handleEditSubtask(subtask),
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
              side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
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
    ).then((updatedTask) {
      if (updatedTask == null) return;
      setState(() {
        _task = updatedTask;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated')),
      );
    });
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete from backend
              Navigator.pop(context); // Go back to task list
              ScaffoldMessenger.of(context).showSnackBar(
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

  void _handleMarkAsCompleted() {
    setState(() {
      _task = _task.copyWith(status: TaskStatus.completed);
    });
    // TODO: Update in backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task marked as completed')),
    );
  }

  void _handleAddSubtask() {
    // TODO: Navigate to add/edit subtask screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add subtask (not implemented yet)')),
    );
  }

  void _handleSubtaskMarkDone(Task subtask) {
    setState(() {
      _subtasks = _subtasks
          .map(
            (t) =>
                t.id == subtask.id ? t.copyWith(status: TaskStatus.completed) : t,
          )
          .toList();
      _sortSubtasks();
    });
    // TODO: Update in backend
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _subtasks.removeWhere((t) => t.id == subtask.id);
              });
              // TODO: Update in backend
              ScaffoldMessenger.of(context).showSnackBar(
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

  void _handleEditSubtask(Task subtask) {
    TaskEditBottomSheet.show(
      context,
      task: subtask,
      sheetTitle: 'Edit Subtask',
    ).then((updatedSubtask) {
      if (updatedSubtask == null) return;
      setState(() {
        _subtasks = _subtasks
            .map(
              (t) => t.id == updatedSubtask.id ? updatedSubtask : t,
            )
            .toList();
        _sortSubtasks();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subtask updated')),
      );
    });
  }

  void _handleMarkAllSubtasksCompleted() {
    setState(() {
      _subtasks = _subtasks
          .map((t) => t.copyWith(status: TaskStatus.completed))
          .toList();
      _sortSubtasks();
    });
    // TODO: Update in backend
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

