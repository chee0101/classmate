import 'package:flutter/material.dart';

import '../common/form_fields.dart';

class TaskCourseFilter extends StatelessWidget {
  const TaskCourseFilter({
    super.key,
    required this.courseCodes,
    required this.selectedCourseCode,
    required this.onChanged,
  });

  final List<String> courseCodes;
  final String? selectedCourseCode;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <DropdownMenuEntry<String?>>[
      const DropdownMenuEntry<String?>(
        value: null,
        label: 'All courses',
      ),
      ...courseCodes.map(
        (code) => DropdownMenuEntry<String?>(
          value: code,
          label: code,
        ),
      ),
    ];

    return DropdownField<String?>(
      label: 'Course',
      value: selectedCourseCode,
      items: entries,
      onChanged: onChanged,
      hintText: 'All courses',
      showLabel: false,
    );
  }
}

