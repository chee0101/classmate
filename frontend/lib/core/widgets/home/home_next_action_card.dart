import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/task.dart';
import '../../utils/date_time_format.dart';

class HomeNextActionCard extends StatelessWidget {
  const HomeNextActionCard({
    super.key,
    required this.nextTask,
    required this.onOpenTask,
    required this.onAddTask,
  });

  final Task? nextTask;
  final VoidCallback onOpenTask;
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: nextTask == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Recommended Action', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'You are all caught up. Add a task to start planning.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onAddTask,
                    child: const Text('Add task'),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Recommended Action', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  nextTask!.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${nextTask!.courseCode} • ${formatRelativeDueDate(nextTask!.dueDateTime)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onOpenTask,
                    child: const Text('Open task'),
                  ),
                ),
              ],
            ),
    );
  }
}
