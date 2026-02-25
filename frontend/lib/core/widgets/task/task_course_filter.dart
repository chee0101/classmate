import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';

class TaskCourseFilter extends StatelessWidget {
  const TaskCourseFilter({
    super.key,
    required this.textTheme,
    required this.courseCodes,
    required this.selectedCourseCode,
    required this.onChanged,
  });

  final TextTheme textTheme;
  final List<String> courseCodes;
  final String? selectedCourseCode;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final menuItemStyle = ButtonStyle(
      textStyle: WidgetStateProperty.all<TextStyle?>(textTheme.bodyLarge),
    );

    final entries = <DropdownMenuEntry<String?>>[
      DropdownMenuEntry<String?>(
        value: null,
        label: 'All courses',
        style: menuItemStyle,
      ),
      ...courseCodes.map(
        (code) => DropdownMenuEntry<String?>(
          value: code,
          label: code,
          style: menuItemStyle,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                blurRadius: 8,
                color: Colors.black12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DropdownMenu<String?>(
            width: width,
            initialSelection: selectedCourseCode,
            onSelected: onChanged,
            dropdownMenuEntries: entries,
            textStyle: textTheme.bodyLarge,
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        );
      },
    );
  }
}

