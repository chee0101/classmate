import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/task.dart';
import '../../services/course_store.dart';
import '../../utils/date_time_format.dart';
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
    _selectedCourseCode = widget.task.courseCode;
    _selectedDueDateTime = widget.task.dueDateTime;

    if (_selectedCourseId != null) {
      final byId = coursesNotifier.value.where((c) => c.id == _selectedCourseId);
      if (byId.isNotEmpty) {
        _scopeSessionId = byId.first.sessionId;
        _scopeTermId = byId.first.termId;
      }
    }

    _selectedCourseId ??= _resolveCourseIdByCode(_selectedCourseCode);
    if (_scopeSessionId == null || _scopeTermId == null) {
      final byCode = coursesNotifier.value.where(
        (c) => c.id == _selectedCourseId,
      );
      if (byCode.isNotEmpty) {
        _scopeSessionId = byCode.first.sessionId;
        _scopeTermId = byCode.first.termId;
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

  List<String> _buildCourseOptions() {
    final sessionId = _scopeSessionId;
    final termId = _scopeTermId;
    final inScope = (sessionId == null || termId == null)
        ? coursesNotifier.value
        : coursesNotifier.value
            .where((c) => c.sessionId == sessionId && c.termId == termId)
            .toList(growable: false);

    final options = inScope.map((c) => c.courseCode).toSet().toList()..sort();
    if (_selectedCourseCode.trim().isNotEmpty &&
        !options.contains(_selectedCourseCode)) {
      options.add(_selectedCourseCode);
      options.sort();
    }
    return options;
  }

  String? _resolveCourseIdByCode(String code) {
    final normalizedCode = code.trim().toUpperCase();
    final sessionId = _scopeSessionId;
    final termId = _scopeTermId;
    final matched = coursesNotifier.value.where((course) {
      final sameScope = sessionId == null || termId == null
          ? true
          : (course.sessionId == sessionId && course.termId == termId);
      return sameScope && course.courseCode.toUpperCase() == normalizedCode;
    });
    return matched.isEmpty ? null : matched.first.id;
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

