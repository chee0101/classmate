import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../utils/date_time_format.dart';
import '../../utils/term_windows.dart';
import '../common/form_fields.dart';
import '../common/course_selector.dart';

class TaskForm extends StatelessWidget {
  const TaskForm({
    super.key,
    required this.titleController,
    required this.noteController,
    required this.dueDateTime,
    required this.selectedTerm,
    required this.courseCodes,
    required this.selectedCourseCode,
    required this.onTitleChanged,
    required this.onCourseChanged,
    required this.onPickDate,
    required this.onPickTime,
  });

  final TextEditingController titleController;
  final TextEditingController noteController;
  final DateTime dueDateTime;
  final TermWindow selectedTerm;
  final List<String> courseCodes;
  final String? selectedCourseCode;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String?> onCourseChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: 'Title',
          hintText: 'Task title',
          controller: titleController,
          onChanged: onTitleChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        CourseSelector(
          courseCodes: courseCodes,
          selected: selectedCourseCode,
          onChanged: onCourseChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TapField(
                label: 'Due Date',
                value: formatDateDdMmYyyy(dueDateTime),
                onTap: onPickDate,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TapField(
                label: 'Due Time',
                value: formatTime12h(dueDateTime),
                onTap: onPickTime,
              ),
            ),
          ],
        ),
        if (!isInTerm(dueDateTime, selectedTerm)) ...[
          const SizedBox(height: 4),
          Text(
            'Due date/time must be within ${selectedTerm.label}.',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: 'Note',
          hintText: 'Enter task details',
          controller: noteController,
          onChanged: (_) {},
          maxLines: 3,
        ),
      ],
    );
  }
}

