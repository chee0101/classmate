import 'package:flutter/material.dart';

import '../common/animated_segmented_switch.dart';

class ScheduleModeToggle extends StatelessWidget {
  const ScheduleModeToggle({
    super.key,
    required this.showMonthly,
    required this.onChanged,
  });

  final bool showMonthly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedSegmentedSwitch<bool>(
      value: showMonthly,
      onChanged: onChanged,
      options: const [
        SegmentedSwitchOption<bool>(value: false, label: 'Weekly'),
        SegmentedSwitchOption<bool>(value: true, label: 'Monthly'),
      ],
    );
  }
}
