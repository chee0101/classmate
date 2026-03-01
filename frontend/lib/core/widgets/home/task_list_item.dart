import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/routes.dart';
import '../../models/task.dart';
import '../../utils/date_time_format.dart';
import '../common/label_chip.dart';

/// A list item widget for displaying a task in the upcoming deadlines list.
class TaskListItem extends StatelessWidget {
  const TaskListItem({
    super.key,
    required this.task,
    required this.textTheme,
  });

  final Task task;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.taskDetail,
          arguments: task,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              LabelChip(
                label: task.courseCode,
                color: task.courseColor,
              ),
              const SizedBox(height: 4),
              Text(
                task.title,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppPrimarySwatch.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Due: ${formatRelativeDueDate(task.dueDateTime)}, ${formatTime12h(task.dueDateTime)}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppPrimarySwatch.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
