import 'package:flutter/material.dart';

import 'form_fields.dart';

class CourseSelector extends StatelessWidget {
  const CourseSelector({
    super.key,
    required this.courseCodes,
    required this.selected,
    required this.onChanged,
    this.onAddCourseRequested,
  });

  final List<String> courseCodes;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final Future<String?> Function()? onAddCourseRequested;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    const addCourseValue = '__add_course__';
    final normalizedSelected = selected?.trim().toUpperCase();
    final effectiveCourseCodes = <String>[
      if (normalizedSelected != null &&
          normalizedSelected.isNotEmpty &&
          !courseCodes.contains(normalizedSelected))
        normalizedSelected,
      ...courseCodes,
    ];
    final entries = <DropdownMenuEntry<String>>[
      ...effectiveCourseCodes.map(
        (code) => DropdownMenuEntry<String>(
          value: code,
          label: code,
        ),
      ),
      DropdownMenuEntry<String>(
        value: addCourseValue,
        label: '+ Add course',
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all<TextStyle?>(
            textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          foregroundColor: WidgetStatePropertyAll<Color?>(colorScheme.primary),
        ),
      ),
    ];

    final currentSelection =
        (normalizedSelected != null &&
            effectiveCourseCodes.contains(normalizedSelected))
        ? normalizedSelected
        : null;

    return DropdownField<String>(
      label: 'Course Code',
      value: currentSelection,
      hintText: courseCodes.isEmpty ? 'No course yet' : 'Select course code',
      items: entries,
      onChanged: (value) async {
        if (value == addCourseValue) {
          if (onAddCourseRequested != null) {
            final newCode = await onAddCourseRequested!();
            if (newCode != null && newCode.trim().isNotEmpty) {
              onChanged(newCode.trim().toUpperCase());
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Add course (mock).'),
              ),
            );
          }
          return;
        }
        onChanged(value);
      },
    );
  }
}

