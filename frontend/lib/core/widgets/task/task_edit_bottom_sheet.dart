import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/task.dart';
import '../../services/course_store.dart';
import '../../utils/date_time_format.dart';

/// Bottom sheet for editing a main Task.
///
/// Returns the updated [Task] via `Navigator.pop(context, updatedTask)`.
class TaskEditBottomSheet extends StatefulWidget {
  const TaskEditBottomSheet({
    super.key,
    required this.task,
    required this.sheetTitle,
    this.isSubtask = false,
    this.parentDueDateTime,
  });

  final Task task;
  final String sheetTitle;
  final bool isSubtask;
  final DateTime? parentDueDateTime;

  static Future<Task?> show(
    BuildContext context, {
    required Task task,
    required String sheetTitle,
    bool isSubtask = false,
    DateTime? parentDueDateTime,
  }) {
    return showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TaskEditBottomSheet(
        task: task,
        sheetTitle: sheetTitle,
        isSubtask: isSubtask,
        parentDueDateTime: parentDueDateTime,
      ),
    );
  }

  @override
  State<TaskEditBottomSheet> createState() => _TaskEditBottomSheetState();
}

class _TaskEditBottomSheetState extends State<TaskEditBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String? _selectedCourseId;
  late String _selectedCourseCode;
  late DateTime _selectedDueDateTime;
  late List<String> _courseOptions;
  String? _titleError;
  String? _timeError;
  bool _hasTime = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController =
        TextEditingController(text: widget.task.description ?? '');
    _selectedCourseId = widget.task.courseId;
    _selectedCourseCode = widget.task.courseCode;
    _selectedDueDateTime = widget.task.dueDateTime;

    _courseOptions =
        coursesNotifier.value.map((course) => course.courseCode).toSet().toList()
          ..sort();
    if (!_courseOptions.contains(_selectedCourseCode)) {
      _courseOptions.add(_selectedCourseCode);
      _courseOptions.sort();
    }
    _selectedCourseId ??= _resolveCourseIdByCode(_selectedCourseCode);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final baseTheme = Theme.of(context);
    final lastDate = widget.isSubtask && widget.parentDueDateTime != null
        ? DateTime(
            widget.parentDueDateTime!.year,
            widget.parentDueDateTime!.month,
            widget.parentDueDateTime!.day,
          )
        : DateTime.now().add(const Duration(days: 365 * 5));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: baseTheme,
          child: child!,
        );
      },
    );
    if (picked != null) {
      final candidate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDueDateTime.hour,
        _selectedDueDateTime.minute,
      );

      setState(() {
        _selectedDueDateTime = candidate;
        _timeError = null;
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
      final candidate = DateTime(
        _selectedDueDateTime.year,
        _selectedDueDateTime.month,
        _selectedDueDateTime.day,
        picked.hour,
        picked.minute,
      );

      if (widget.isSubtask &&
          widget.parentDueDateTime != null &&
          candidate.isAfter(widget.parentDueDateTime!)) {
        setState(() {
          _hasTime = false;
          _timeError =
              'Subtask due time must be on or before the main task due time.';
        });
        return;
      }

      setState(() {
        _selectedDueDateTime = candidate;
        _hasTime = true;
        _timeError = null;
      });
    }
  }

  void _handleSave() {
    final trimmedTitle = _titleController.text.trim();
    if (trimmedTitle.isEmpty) {
      setState(() {
        _titleError = 'Title cannot be empty';
      });
      return;
    } else {
      _titleError = null;
    }

    if (widget.isSubtask && widget.parentDueDateTime != null) {
      if (_selectedDueDateTime.isAfter(widget.parentDueDateTime!)) {
        setState(() {
          _timeError =
              'Subtask due date/time must be on or before the main task.';
        });
        return;
      } else {
        _timeError = null;
        _hasTime = true;
      }
    }

    final updated = widget.task.copyWith(
      title: trimmedTitle,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      courseId: _selectedCourseId,
      courseCode: _selectedCourseCode,
      dueDateTime: _selectedDueDateTime,
    );
    Navigator.pop(context, updated);
  }

  String? _resolveCourseIdByCode(String code) {
    final normalizedCode = code.trim().toUpperCase();
    final matched = coursesNotifier.value.where((course) {
      return course.courseCode.toUpperCase() == normalizedCode;
    });
    return matched.isEmpty ? null : matched.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _titleController.text.trim().isNotEmpty &&
        _titleError == null &&
        _timeError == null &&
        (!widget.isSubtask || _hasTime);
    return SingleChildScrollView(
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
            onChanged: (_) {
              if (_titleError != null) {
                setState(() => _titleError = null);
              }
            },
          ),
          if (_titleError != null) ...[
            const SizedBox(height: 4),
            Text(
              _titleError!,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _selectedCourseCode,
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
            onChanged: widget.isSubtask
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedCourseCode = value;
                      _selectedCourseId = _resolveCourseIdByCode(value);
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
                          _hasTime
                              ? formatTime12h(_selectedDueDateTime)
                              : 'Select time',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: _hasTime
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade500,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_timeError != null) ...[
            const SizedBox(height: 4),
            Text(
              _timeError!,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ],
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
              onPressed: canSave ? _handleSave : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

