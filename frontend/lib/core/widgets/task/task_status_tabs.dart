import 'package:flutter/material.dart';

import '../../models/task.dart';

class TaskStatusTabs extends StatelessWidget {
  const TaskStatusTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TaskStatus selected;
  final ValueChanged<TaskStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget buildTab(TaskStatus status, String label) {
      final bool isActive = selected == status;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(status),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? colorScheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          buildTab(TaskStatus.ongoing, 'Ongoing'),
          const SizedBox(width: 4),
          buildTab(TaskStatus.overdue, 'Overdue'),
          const SizedBox(width: 4),
          buildTab(TaskStatus.completed, 'Complete'),
        ],
      ),
    );
  }
}

