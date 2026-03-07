import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../common/animated_segmented_switch.dart';

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
    return AnimatedSegmentedSwitch<TaskStatus>(
      value: selected,
      onChanged: onChanged,
      options: const [
        SegmentedSwitchOption<TaskStatus>(
          value: TaskStatus.ongoing,
          label: 'Ongoing',
        ),
        SegmentedSwitchOption<TaskStatus>(
          value: TaskStatus.overdue,
          label: 'Overdue',
        ),
        SegmentedSwitchOption<TaskStatus>(
          value: TaskStatus.completed,
          label: 'Complete',
        ),
      ],
    );
  }
}

