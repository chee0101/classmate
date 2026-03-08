import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/task.dart';
import '../../utils/date_time_format.dart';
import '../common/label_chip.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onMarkDone,
    this.onTap,
    this.showMarkDone = true,
    this.nextSubtaskTitle,
    this.footer,
  });

  final Task task;
  final VoidCallback onMarkDone;
  final VoidCallback? onTap;
  final bool showMarkDone;
  final String? nextSubtaskTitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final dueDateStr =
        '${formatRelativeDueDate(task.dueDateTime)}, ${formatTime12h(task.dueDateTime)}';

    final mainContent = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
            LabelChip(
              label: task.courseCode,
              color: task.courseColor,
            ),
            const Spacer(),
            if (task.status == TaskStatus.overdue)
              const LabelChip(
                label: 'Overdue',
                background: Color(0xFFFFE5E5),
                foreground: Color(0xFFE53935),
              )
            else if (task.status == TaskStatus.ongoing)
              const LabelChip(
                label: 'Ongoing',
                background: Color(0xFFFFF3CD),
                foreground: Color(0xFFF9A825),
              )
            else
              LabelChip(
                label: 'Completed',
                background: colorScheme.primary.withOpacity(0.1),
                foreground: colorScheme.primary,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          task.title,
          style: textTheme.titleMedium,
        ),
        if (task.description != null) ...[
          const SizedBox(height: 4),
          Text(
            task.description!,
            style: textTheme.bodyLarge,
          ),
        ],
        if (nextSubtaskTitle != null) ...[
          const SizedBox(height: 4),
          Text(
            'Next: $nextSubtaskTitle',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                'Due: $dueDateStr',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            if (task.status != TaskStatus.completed && showMarkDone)
              const SizedBox(width: 8),
            if (task.status != TaskStatus.completed && showMarkDone)
              TextButton(
                onPressed: onMarkDone,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Mark as completed',
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

    final cardContent = Container(
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mainContent,
          if (footer != null) ...[
            const Divider(height: 1),
            footer!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      );
    }

    return cardContent;
  }

}

