import 'package:flutter/material.dart';

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
  final VoidCallback? onAddCourseRequested;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final menuItemStyle = ButtonStyle(
      textStyle: WidgetStateProperty.all<TextStyle?>(textTheme.bodyLarge),
    );
    const addCourseValue = '__add_course__';
    final entries = <DropdownMenuEntry<String>>[
      ...courseCodes.map(
        (code) => DropdownMenuEntry<String>(
          value: code,
          label: code,
          style: menuItemStyle,
        ),
      ),
      DropdownMenuEntry<String>(
        value: addCourseValue,
        label: '+ Add course',
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all<TextStyle?>(
            textTheme.bodyLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          foregroundColor:
              WidgetStatePropertyAll<Color?>(colorScheme.primary),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Course Code', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final currentSelection =
                (selected != null && courseCodes.contains(selected))
                    ? selected
                    : null;
            return DropdownMenu<String>(
              key: ValueKey(currentSelection),
              width: constraints.maxWidth,
              hintText: courseCodes.isEmpty
                  ? 'No course yet'
                  : 'Select course code',
              initialSelection: currentSelection,
              dropdownMenuEntries: entries,
              onSelected: (value) {
                if (value == addCourseValue) {
                  if (onAddCourseRequested != null) {
                    onAddCourseRequested!();
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
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                hintStyle: textTheme.bodyLarge,
                labelStyle: textTheme.bodyLarge,
              ),
            );
          },
        ),
      ],
    );
  }
}

