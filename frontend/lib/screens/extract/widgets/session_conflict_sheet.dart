import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

enum SessionConflictAction { merge, addNew, replace, cancel }

class SessionConflictSheet extends StatelessWidget {
  const SessionConflictSheet({
    super.key,
    required this.sessionName,
    required this.sessionRangeText,
  });

  final String sessionName;
  final String sessionRangeText;

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
              'Session already exists',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A session with the same dates was found:',
              style: textTheme.bodyMedium?.copyWith(
                color: appPrimarySwatch.shade700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$sessionName ($sessionRangeText)',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            _ConflictOptionCard(
              title: 'Merge with existing',
              subtitle: 'Combine extracted holidays with current session',
              emphasized: true,
              onTap: () => Navigator.of(context).pop(SessionConflictAction.merge),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ConflictOptionCard(
              title: 'Add as new session',
              subtitle: 'Create a separate session with same dates',
              onTap: () => Navigator.of(context).pop(SessionConflictAction.addNew),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ConflictOptionCard(
              title: 'Replace existing session',
              subtitle: 'This will overwrite all existing data',
              warning: true,
              onTap: () => Navigator.of(context).pop(SessionConflictAction.replace),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(SessionConflictAction.cancel),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictOptionCard extends StatelessWidget {
  const _ConflictOptionCard({
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
