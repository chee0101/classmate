import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/task.dart';
import '../../services/course_store.dart';
import '../../utils/date_time_format.dart';
import '../common/confirm_dialog.dart';
import '../common/course_selector.dart';
import '../common/form_fields.dart';
import '../add/add_course_dialog.dart';

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
    this.onDeleteRequested,
    this.deleteConfirmTitle,
    this.deleteConfirmMessage,
    this.deleteConfirmText = 'Delete',
    this.scopeSessionId,
    this.scopeTermId,
    this.minDueDateTime,
    this.maxDueDateTime,
  });

  final Task task;
  final String sheetTitle;
  final bool isSubtask;
  final DateTime? parentDueDateTime;
  final VoidCallback? onDeleteRequested;
  final String? deleteConfirmTitle;
  final String? deleteConfirmMessage;
  final String deleteConfirmText;
  final String? scopeSessionId;
  final String? scopeTermId;
  final DateTime? minDueDateTime;
  final DateTime? maxDueDateTime;

  static Future<Task?> show(
    BuildContext context, {
    required Task task,
    required String sheetTitle,
    bool isSubtask = false,
    DateTime? parentDueDateTime,
    VoidCallback? onDeleteRequested,
    String? deleteConfirmTitle,
    String? deleteConfirmMessage,
    String deleteConfirmText = 'Delete',
    String? scopeSessionId,
    String? scopeTermId,
    DateTime? minDueDateTime,
    DateTime? maxDueDateTime,
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
        onDeleteRequested: onDeleteRequested,
        deleteConfirmTitle: deleteConfirmTitle,
        deleteConfirmMessage: deleteConfirmMessage,
        deleteConfirmText: deleteConfirmText,
        scopeSessionId: scopeSessionId,
        scopeTermId: scopeTermId,
        minDueDateTime: minDueDateTime,
        maxDueDateTime: maxDueDateTime,
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
  String? _scopeSessionId;
  String? _scopeTermId;
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
    var initialCode = widget.task.courseCode;
    final cid = _selectedCourseId;
    if (cid != null && cid.isNotEmpty) {
      for (final c in coursesNotifier.value) {
        if (c.id == cid) {
          initialCode = c.courseCode;
          break;
        }
      }
    }
    _selectedCourseCode = initialCode;
    _selectedDueDateTime = widget.task.dueDateTime;

    _scopeSessionId = widget.scopeSessionId;
    _scopeTermId = widget.scopeTermId;

    if (_selectedCourseId != null &&
        (_scopeSessionId == null || _scopeTermId == null)) {
      final scope = courseScopeForCourseId(_selectedCourseId!);
      _scopeSessionId = scope?.sessionId;
      _scopeTermId = scope?.termId;
    }

    _selectedCourseId ??= _resolveCourseIdByCode(_selectedCourseCode);
    if (_scopeSessionId == null || _scopeTermId == null) {
      if (_selectedCourseId != null) {
        final scope = courseScopeForCourseId(_selectedCourseId!);
        _scopeSessionId = scope?.sessionId;
        _scopeTermId = scope?.termId;
      }
    }

    _courseOptions = _buildCourseOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final baseTheme = Theme.of(context);
    var lastDate = widget.isSubtask && widget.parentDueDateTime != null
        ? DateTime(
            widget.parentDueDateTime!.year,
            widget.parentDueDateTime!.month,
            widget.parentDueDateTime!.day,
          )
        : DateTime.now().add(const Duration(days: 365 * 5));
    if (widget.maxDueDateTime != null && widget.maxDueDateTime!.isBefore(lastDate)) {
      lastDate = DateTime(
        widget.maxDueDateTime!.year,
        widget.maxDueDateTime!.month,
        widget.maxDueDateTime!.day,
      );
    }

    var firstDate = DateTime.now().subtract(const Duration(days: 365));
    if (widget.minDueDateTime != null && widget.minDueDateTime!.isAfter(firstDate)) {
      firstDate = DateTime(
        widget.minDueDateTime!.year,
        widget.minDueDateTime!.month,
        widget.minDueDateTime!.day,
      );
    }
    if (lastDate.isBefore(firstDate)) {
      firstDate = DateTime(lastDate.year, lastDate.month, lastDate.day);
    }

    var initialDate = _selectedDueDateTime;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
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
      if (widget.maxDueDateTime != null && candidate.isAfter(widget.maxDueDateTime!)) {
        setState(() {
          _timeError = 'Due date/time must be within the selected session range.';
        });
        return;
      }
      if (widget.minDueDateTime != null && candidate.isBefore(widget.minDueDateTime!)) {
        setState(() {
          _timeError = 'Due date/time must be within the selected session range.';
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

    if (widget.maxDueDateTime != null &&
        _selectedDueDateTime.isAfter(widget.maxDueDateTime!)) {
      setState(() {
        _timeError = 'Due date/time must be within the selected session range.';
      });
      return;
    }
    if (widget.minDueDateTime != null &&
        _selectedDueDateTime.isBefore(widget.minDueDateTime!)) {
      setState(() {
        _timeError = 'Due date/time must be within the selected session range.';
      });
      return;
    }

    var courseColor = widget.task.courseColor;
    final selectedId = _selectedCourseId;
    if (selectedId != null && selectedId.isNotEmpty) {
      for (final c in coursesNotifier.value) {
        if (c.id == selectedId) {
          final v = int.tryParse(c.courseColor.replaceFirst('#', '0xFF'));
          courseColor = Color(v ?? 0xFF6C4DD9);
          break;
        }
      }
    }

    final updated = widget.task.copyWith(
      title: trimmedTitle,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      courseId: _selectedCourseId,
      courseCode: _selectedCourseCode,
      courseColor: courseColor,
      dueDateTime: _selectedDueDateTime,
    );
    Navigator.pop(context, updated);
  }

  List<String> _buildCourseOptions() {
    final sessionId = _scopeSessionId;
    final termId = _scopeTermId;
    if (sessionId == null || termId == null) {
      final options = coursesNotifier.value
          .map((c) => c.courseCode.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
      final selected = _selectedCourseCode.trim().toUpperCase();
      if (selected.isNotEmpty && !options.contains(selected)) {
        return ([...options, selected]..sort());
      }
      return options;
    }
    return courseCodesForSessionAndTerm(
      sessionId: sessionId,
      termId: termId,
      includeCode: _selectedCourseCode,
    );
  }

  String? _resolveCourseIdByCode(String code) {
    final sessionId = _scopeSessionId;
    final termId = _scopeTermId;
    if (sessionId == null || termId == null) {
      final normalizedCode = code.trim().toUpperCase();
      final matched = coursesNotifier.value.where((course) {
        return course.courseCode.toUpperCase() == normalizedCode;
      });
      return matched.isEmpty ? null : matched.first.id;
    }
    return resolveCourseIdByCodeInSessionAndTerm(
      sessionId: sessionId,
      termId: termId,
      courseCode: code,
    );
  }

  Future<String?> _addCourseRequested() async {
    final sessionId = _scopeSessionId;
    final termId = _scopeTermId;
    if (sessionId == null || termId == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to determine academic session/term for this task.'),
        ),
      );
      return null;
    }
    return CourseDialog.show(
      context,
      sessionId: sessionId,
      termId: termId,
    );
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
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.sheetTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (widget.onDeleteRequested != null)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirmed = await showConfirmDeleteDialog(
                      context,
                      title: widget.deleteConfirmTitle ?? 'Delete Task',
                      message:
                          widget.deleteConfirmMessage ??
                          'Are you sure you want to delete this task?',
                      confirmText: widget.deleteConfirmText,
                    );
                    if (!confirmed || !context.mounted) return;
                    widget.onDeleteRequested?.call();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledTextField(
            label: 'Title',
            hintText: 'Task title',
            controller: _titleController,
            errorText: _titleError,
            onChanged: (_) {
              if (_titleError != null) {
                setState(() => _titleError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          CourseSelector(
            courseCodes: _courseOptions,
            selected: _selectedCourseCode,
            enabled: !widget.isSubtask,
            onAddCourseRequested: widget.isSubtask ? null : _addCourseRequested,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedCourseCode = value;
                _selectedCourseId = _resolveCourseIdByCode(value);
                final matched = coursesNotifier.value.where((c) => c.id == _selectedCourseId);
                if (matched.isNotEmpty) {
                  _scopeSessionId = matched.first.sessionId;
                  _scopeTermId = matched.first.termId;
                }
                _courseOptions = _buildCourseOptions();
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TapField(
                  label: 'Due Date',
                  value: formatDateDdMmYyyy(_selectedDueDateTime),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TapField(
                  label: 'Due Time',
                  value:
                      _hasTime ? formatTime12h(_selectedDueDateTime) : 'Select time',
                  onTap: _pickTime,
                  hintText: 'Select time',
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
          LabeledTextField(
            label: 'Note (Optional)',
            hintText: 'Enter task details',
            controller: _descriptionController,
            onChanged: (_) {},
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

