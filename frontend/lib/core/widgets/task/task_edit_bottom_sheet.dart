import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../mock/mock_tasks.dart';
import '../../models/task.dart';
import '../../utils/date_time_format.dart';

/// Bottom sheet for editing a main Task.
///
/// Returns the updated [Task] via `Navigator.pop(context, updatedTask)`.
class TaskEditBottomSheet extends StatefulWidget {
  const TaskEditBottomSheet({
    super.key,
    required this.task,
    required this.sheetTitle,
  });

  final Task task;
  final String sheetTitle;

  static Future<Task?> show(
    BuildContext context, {
    required Task task,
    required String sheetTitle,
  }) {
    return showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          TaskEditBottomSheet(task: task, sheetTitle: sheetTitle),
    );
  }

  @override
  State<TaskEditBottomSheet> createState() => _TaskEditBottomSheetState();
}

class _TaskEditBottomSheetState extends State<TaskEditBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _selectedCourseCode;
  late DateTime _selectedDueDateTime;
  late List<String> _courseOptions;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController =
        TextEditingController(text: widget.task.description ?? '');
    _selectedCourseCode = widget.task.courseCode;
    _selectedDueDateTime = widget.task.dueDateTime;

    _courseOptions = mockTasks.map((t) => t.courseCode).toSet().toList()
      ..sort();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final baseTheme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: baseTheme,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDueDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDueDateTime.hour,
          _selectedDueDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final baseTheme = Theme.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDueDateTime),
      builder: (context, child) {
        return Theme(
          data: baseTheme,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDueDateTime = DateTime(
          _selectedDueDateTime.year,
          _selectedDueDateTime.month,
          _selectedDueDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _handleSave() {
    final updated = widget.task.copyWith(
      title: _titleController.text.trim().isEmpty
          ? widget.task.title
          : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      courseCode: _selectedCourseCode,
      dueDateTime: _selectedDueDateTime,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.sheetTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: _selectedCourseCode,
            decoration: const InputDecoration(
              labelText: 'Course code',
            ),
            items: _courseOptions
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(code),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedCourseCode = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Due date',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          formatDateDdMmYyyy(_selectedDueDateTime),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.grey.shade800,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Due time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          formatTime12h(_selectedDueDateTime),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.grey.shade800,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSave,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

