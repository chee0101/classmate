import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/weekdays.dart';
import '../../models/class_type.dart';
import '../../models/timetable_entry.dart';
import '../../utils/date_time_format.dart';

String _formatSlotLocation(TimetableSlot slot) {
  if (slot.mode == 'Online') return 'Online';
  final venue = slot.venue?.trim();
  return (venue == null || venue.isEmpty) ? '-' : venue;
}

class _TimetableCardShell extends StatelessWidget {
  const _TimetableCardShell({
    required this.courseCode,
    required this.courseColor,
    required this.child,
    this.headerLeading,
    this.onTap,
    this.onDelete,
  });

  final String courseCode;
  final Color courseColor;
  final Widget child;
  final Widget? headerLeading;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (headerLeading != null) ...[
                      headerLeading!,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: courseColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        courseCode,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                      ),
                  ],
                ),
                if (child is! SizedBox) ...[
                  const SizedBox(height: AppSpacing.sm),
                  child,
                ] else
                  child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimetableSlotMeta extends StatelessWidget {
  const _TimetableSlotMeta({
    required this.slot,
  });

  final TimetableSlot slot;

  @override
  Widget build(BuildContext context) {
    final location = _formatSlotLocation(slot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 16,
              color: Color(0xFF6043BF),
            ),
            const SizedBox(width: 8),
            Text(
              '${slot.startTime} – ${slot.endTime}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: Color(0xFF6043BF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${slot.classType.label} • $location',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TimetableCourseCard extends StatelessWidget {
  const TimetableCourseCard({
    super.key,
    required this.courseCode,
    required this.slots,
    required this.courseColor,
    this.headerLeading,
    this.onTap,
    this.onDelete,
  });

  final String courseCode;
  final List<TimetableSlot> slots;
  final Color courseColor;
  final Widget? headerLeading;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  int _slotStartMinutes(TimetableSlot slot) {
    return parseTimeLabel12hToMinutes(slot.startTime.trim()) ?? 0;
  }

  Map<String, List<TimetableSlot>> _groupSlotsByDay(List<TimetableSlot> slots) {
    final grouped = <String, List<TimetableSlot>>{};
    for (final slot in slots) {
      grouped.putIfAbsent(slot.day, () => <TimetableSlot>[]).add(slot);
    }
    for (final day in grouped.keys) {
      grouped[day]!.sort(
        (a, b) => _slotStartMinutes(a).compareTo(_slotStartMinutes(b)),
      );
    }
    return grouped;
  }

  List<String> _sortedDays(Iterable<String> days) {
    final sorted = days.toList(growable: false);
    sorted.sort((a, b) {
      final ai = weekdayOrderFromString(a);
      final bi = weekdayOrderFromString(b);
      if (ai == 99 && bi == 99) return a.compareTo(b);
      if (ai == 99) return 1;
      if (bi == 99) return -1;
      return ai.compareTo(bi);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupSlotsByDay(slots);
    final days = _sortedDays(grouped.keys);

    return _TimetableCardShell(
      courseCode: courseCode,
      courseColor: courseColor,
      headerLeading: headerLeading,
      onTap: onTap,
      onDelete: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(days.length, (index) {
          final day = days[index];
          final daySlots = grouped[day]!;

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == days.length - 1 ? 0 : AppSpacing.md,
            ),
            child: SizedBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.length >= 3 ? day.substring(0, 3) : day,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF6043BF),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ...daySlots.map(
                    (slot) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _TimetableSlotMeta(slot: slot),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
