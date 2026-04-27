import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/task.dart';

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

  String _relativeDayLabel(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;
    if (diff == 0) return 'due today';
    if (diff < 0) {
      final daysAgo = -diff;
      return '$daysAgo day${daysAgo == 1 ? '' : 's'} ago';
    }
    return '$diff day${diff == 1 ? '' : 's'} left';
  }

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nextTask!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${nextTask!.courseCode} • ${_relativeDayLabel(nextTask!.dueDateTime)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: onOpenTask,
                      child: const Text('View'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
