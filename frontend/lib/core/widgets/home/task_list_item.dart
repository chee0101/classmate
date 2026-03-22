import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/routes.dart';
import '../../models/course.dart';
import '../../models/task.dart';
import '../../utils/course_display.dart';
import '../../utils/date_time_format.dart';
import '../common/label_chip.dart';

/// A list item widget for displaying a task in the upcoming deadlines list.
class TaskListItem extends StatelessWidget {
  const TaskListItem({
    super.key,
    required this.task,
    required this.textTheme,
    this.courses,
  });

  final Task task;
  final TextTheme textTheme;
  final List<Course>? courses;

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
                label: courses == null
                    ? task.courseCode
                    : displayCourseCodeForTask(task, courses!),
                color: courses == null
                    ? task.courseColor
                    : displayCourseColorForTask(task, courses!),
              ),
              const SizedBox(height: 4),
              Text(
                task.title,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: appPrimarySwatch.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Due: ${formatRelativeDueDate(task.dueDateTime)}, ${formatTime12h(task.dueDateTime)}',
                style: textTheme.bodySmall?.copyWith(
                  color: appPrimarySwatch.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
