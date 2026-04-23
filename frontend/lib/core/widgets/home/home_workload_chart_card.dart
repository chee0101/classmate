import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';

class HomeWorkloadChartCard extends StatelessWidget {
  const HomeWorkloadChartCard({
    super.key,
    required this.weekLabels,
    required this.weekCounts,
  });

  final List<String> weekLabels;
  final List<int> weekCounts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final safeLabels = weekLabels;
    final safeCounts = weekCounts;
    final itemCount = safeCounts.length;
    if (itemCount == 0 || safeLabels.length != safeCounts.length) {
      return const SizedBox.shrink();
    }
    final maxCount = safeCounts.reduce((a, b) => a > b ? a : b);
    final peakValue = maxCount;
    final peakIndex = safeCounts.indexOf(peakValue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workload (Next 4 Weeks)', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 136,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(itemCount, (index) {
                final count = safeCounts[index];
                final normalized = maxCount == 0 ? 0.0 : (count / maxCount);
                final barFactor = maxCount == 0 ? 0.12 : (0.12 + (0.88 * normalized));
                final isPeak = count > 0 && count == peakValue;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : AppSpacing.xs,
                      right: index == itemCount - 1 ? 0 : AppSpacing.xs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: barFactor,
                              widthFactor: 1,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOut,
                                decoration: BoxDecoration(
                                  color: isPeak
                                      ? Colors.orange.shade600
                                      : appPrimarySwatch.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          safeLabels[index],
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            peakValue == 0
                ? 'No task deadlines in the next 4 weeks.'
                : 'Peak: Week ${peakIndex + 1} ($peakValue tasks)',
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
