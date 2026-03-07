import 'package:flutter/material.dart';

class SessionTermContextLabel extends StatelessWidget {
  const SessionTermContextLabel({
    super.key,
    required this.sessionName,
    required this.termLabel,
  });

  final String sessionName;
  final String termLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$sessionName · $termLabel',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
