import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/academic_event.dart';
import '../../utils/term_windows.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.selectedTerm,
    required this.events,
    required this.selectedSessionId,
  });

  final TermWindow selectedTerm;
  final List<AcademicEvent> events;
  final String selectedSessionId;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final contextInfo = _buildInsightContext(
      selectedTerm: selectedTerm,
      selectedSessionId: selectedSessionId,
      events: events,
      now: now,
    );
    if (contextInfo == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Week ${contextInfo.weekNumber} • ${contextInfo.phase}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              contextInfo.milestoneLine,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
    ]);
  }
}

class _InsightContext {
  const _InsightContext({
    required this.weekNumber,
    required this.phase,
    required this.milestoneLine,
  });

  final int weekNumber;
  final String phase;
  final String milestoneLine;
}

_InsightContext? _buildInsightContext({
  required TermWindow selectedTerm,
  required String selectedSessionId,
  required List<AcademicEvent> events,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final termStart = DateTime(
    selectedTerm.start.year,
    selectedTerm.start.month,
    selectedTerm.start.day,
  );
  final termEnd = DateTime(
    selectedTerm.end.year,
    selectedTerm.end.month,
    selectedTerm.end.day,
  );

  if (today.isBefore(termStart) || today.isAfter(termEnd)) {
    return null;
  }

  final weekNumber = (today.difference(termStart).inDays ~/ 7) + 1;
  final termBreaks = events
      .where(
        (e) =>
            e.sessionId == selectedSessionId &&
            e.termId == selectedTerm.id &&
            e.isAcademicBreak,
      )
      .toList(growable: false)
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

  AcademicEvent? currentBreak;
  for (final event in termBreaks) {
    final start = DateTime(
      event.startDateTime.year,
      event.startDateTime.month,
      event.startDateTime.day,
    );
    final end = DateTime(
      event.endDateTime.year,
      event.endDateTime.month,
      event.endDateTime.day,
    );
    if (!today.isBefore(start) && !today.isAfter(end)) {
      currentBreak = event;
      break;
    }
  }

  final phase = currentBreak != null
      ? _normalizePhaseLabel(currentBreak.title)
      : _phaseFromWeek(
          weekNumber: weekNumber,
          term: selectedTerm,
        );

  if (phase == null || phase.isEmpty) {
    return null;
  }

  late final String milestoneLine;
  if (currentBreak != null) {
    final endDay = DateTime(
      currentBreak.endDateTime.year,
      currentBreak.endDateTime.month,
      currentBreak.endDateTime.day,
    );
    final daysLeft = endDay.difference(today).inDays;
    milestoneLine = 'Ends in $daysLeft day${daysLeft == 1 ? '' : 's'}';
  } else {
    AcademicEvent? nextBreak;
    for (final event in termBreaks) {
      final startDay = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      if (startDay.isAfter(today)) {
        nextBreak = event;
        break;
      }
    }
    if (nextBreak == null) return null;

    final nextStart = DateTime(
      nextBreak.startDateTime.year,
      nextBreak.startDateTime.month,
      nextBreak.startDateTime.day,
    );
    final daysUntil = nextStart.difference(today).inDays;
    final label = _shortMilestoneLabel(nextBreak.title);
    milestoneLine =
        'Next: $label in $daysUntil day${daysUntil == 1 ? '' : 's'}';
  }

  return _InsightContext(
    weekNumber: weekNumber,
    phase: phase,
    milestoneLine: milestoneLine,
  );
}

String _normalizePhaseLabel(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('teaching')) return 'Teaching & Learning';
  if (lower.contains('mid') && lower.contains('break'))
    return 'Mid-Semester Break';
  if (lower.contains('revision')) return 'Revision Week';
  if (lower.contains('exam')) return 'Exam Week';
  if (lower.contains('long') && lower.contains('break')) return 'Long Break';
  if (lower.contains('break')) return 'Long Break';
  return raw;
}

String _shortMilestoneLabel(String raw) {
  final normalized = _normalizePhaseLabel(raw);
  if (normalized == 'Mid-Semester Break') return 'Mid-Sem Break';
  return normalized;
}

String? _phaseFromWeek({
  required int weekNumber,
  required TermWindow term,
}) {
  final lowerLabel = term.label.toLowerCase();
  final isSem1 = term.id == 'sem1' || lowerLabel.contains('semester 1');
  final isSem2 = term.id == 'sem2' || lowerLabel.contains('semester 2');

  if (!isSem1 && !isSem2) {
    return 'Teaching & Learning';
  }

  if (weekNumber >= 1 && weekNumber <= 7) return 'Teaching & Learning';
  if (weekNumber == 8) return 'Mid-Semester Break';
  if (weekNumber >= 9 && weekNumber <= 15) return 'Teaching & Learning';
  if (weekNumber == 16) return 'Revision Week';
  if (weekNumber >= 17 && weekNumber <= 19) return 'Exam Week';
  if (isSem2) return 'Long Break';
  return 'Mid-Semester Break';
}
