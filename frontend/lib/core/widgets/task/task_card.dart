import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/task.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onMarkDone,
  });

  final Task task;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final dueDateStr =
        '${_formatRelativeDueDate(task.dueDateTime)}, ${_formatTime(task.dueDateTime)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: task.courseColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  task.courseCode,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: task.courseColor,
                  ),
                ),
              ),
              const Spacer(),
              if (task.status == TaskStatus.overdue)
                const _StatusPill(
                  label: 'Overdue',
                  background: Color(0xFFFFE5E5),
                  foreground: Color(0xFFE53935),
                )
              else if (task.status == TaskStatus.ongoing)
                const _StatusPill(
                  label: 'Ongoing',
                  background: Color(0xFFFFF3CD),
                  foreground: Color(0xFFF9A825),
                )
              else
                _StatusPill(
                  label: 'Completed',
                  background: colorScheme.primary.withOpacity(0.1),
                  foreground: colorScheme.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            task.title,
            style: textTheme.headlineMedium,
          ),
          if (task.description != null) ...[
            const SizedBox(height: 4),
            Text(
              task.description!,
              style: textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                'Due: $dueDateStr',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              if (task.status != TaskStatus.completed)
                TextButton(
                  onPressed: onMarkDone,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Mark as Done',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRelativeDueDate(DateTime dt) {
    final now = DateTime.now();
    final difference = dt.difference(
      DateTime(now.year, now.month, now.day),
    );

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 0) {
      final daysAgo = -difference.inDays;
      return daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago';
    } else {
      return '${dt.day} ${_monthLabel(dt.month)}';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

