import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';

class HomeOverviewCards extends StatelessWidget {
  const HomeOverviewCards({
    super.key,
    required this.pendingCount,
    required this.overdueCount,
    required this.busiestWeekLabel,
    required this.busiestWeekCount,
  });

  final int pendingCount;
  final int overdueCount;
  final String busiestWeekLabel;
  final int busiestWeekCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Pending',
            value: '$pendingCount',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCard(
            label: 'Overdue',
            value: '$overdueCount',
            color: overdueCount > 0 ? Colors.red.shade600 : Colors.green.shade600,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCard(
            label: busiestWeekLabel,
            value: '$busiestWeekCount',
            color: Colors.orange.shade700,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
