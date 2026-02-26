import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/task.dart';
import '../../utils/date_time_format.dart';

class SubtaskCard extends StatelessWidget {
  const SubtaskCard({
    super.key,
    required this.subtask,
    required this.onMarkDone,
    required this.onEdit,
    required this.onDelete,
    required this.isEditing,
  });

  final Task subtask;
  final VoidCallback onMarkDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final dueDateStr =
        '${formatRelativeDueDate(subtask.dueDateTime)}, ${formatTime12h(subtask.dueDateTime)}';

    final isCompleted = subtask.status == TaskStatus.completed;

    final mainContent = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtask.status == TaskStatus.overdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Overdue',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFE53935),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (subtask.status == TaskStatus.ongoing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ongoing',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFF9A825),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtask.title,
                  style: textTheme.titleLarge,
                ),
                if (subtask.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtask.description!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Due: $dueDateStr',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          InkWell(
            onTap: isCompleted ? null : onMarkDone,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isCompleted ? colorScheme.primary : Colors.grey.shade400,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: isCompleted ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mainContent,
            if (isEditing) ...[
              const Divider(height: 1),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onEdit,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
