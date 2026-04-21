import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';

enum TimetableSaveModeAction { merge, replace, cancel }

class TimetableSaveModeSheet extends StatelessWidget {
  const TimetableSaveModeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save timetable',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose how to apply selected courses.',
              style: textTheme.bodyMedium?.copyWith(
                color: appPrimarySwatch.shade700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ModeOptionCard(
              title: 'Merge with existing',
              subtitle: 'Keep existing slots and add new unique ones',
              emphasized: true,
              onTap: () => Navigator.of(context).pop(TimetableSaveModeAction.merge),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ModeOptionCard(
              title: 'Replace selected courses',
              subtitle: 'Overwrite selected courses with reviewed slots',
              warning: true,
              onTap: () => Navigator.of(context).pop(TimetableSaveModeAction.replace),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(TimetableSaveModeAction.cancel),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
    this.warning = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bgColor = emphasized ? appPrimarySwatch.shade700 : Colors.white;
    final borderColor = emphasized ? appPrimarySwatch.shade700 : Colors.grey.shade300;
    final titleColor = emphasized
        ? Colors.white
        : warning
            ? Colors.red.shade700
            : textTheme.bodyLarge?.color;
    final subtitleColor = emphasized ? Colors.white70 : Colors.grey.shade700;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                warning ? '⚠ $title' : title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(color: subtitleColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
