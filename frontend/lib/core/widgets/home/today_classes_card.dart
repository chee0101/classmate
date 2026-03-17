import 'package:flutter/material.dart';

import '../common/empty_state_card.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../../screens/add/add_new_screen.dart' show AddType;
import '../../models/timetable_entry.dart';
import '../../utils/date_time_format.dart';

class TodayClassItem {
  const TodayClassItem({
    required this.slot,
    required this.courseCode,
    required this.courseColor,
  });

  final TimetableSlot slot;
  final String courseCode;
  final Color courseColor;
}

/// A card widget that displays today's classes or an empty state.
class TodayClassesCard extends StatelessWidget {
  const TodayClassesCard({
    super.key,
    required this.items,
  });

  final List<TodayClassItem> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    String _formatTime24h(String label) {
      final minutes = parseTimeLabel12hToMinutes(label);
      if (minutes == null) return label;
      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }

    if (items.isEmpty) {
      return EmptyStateCard(
        icon: Icons.event_busy,
        title: "Today's Classes",
        subtitle: 'No timetable added yet.',
        buttonText: 'Add class',
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.addNew,
            arguments: AddType.classSlot,
          );
        },
      );
    }

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
          Text(
            "Today's Classes",
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) {
            final slot = item.slot;
            final startLabel = _formatTime24h(slot.startTime);
            final endLabel = _formatTime24h(slot.endTime);
            final venueLabel = slot.mode == 'Online'
                ? 'Online'
                : (slot.venue?.trim().isEmpty ?? true)
                    ? '-'
                    : slot.venue!.trim();

            final startMinutes = parseTimeLabel12hToMinutes(slot.startTime);
            final endMinutes = parseTimeLabel12hToMinutes(slot.endTime);
            final now = TimeOfDay.now();
            final nowMinutes = now.hour * 60 + now.minute;
            final isNow = startMinutes != null &&
                endMinutes != null &&
                nowMinutes >= startMinutes &&
                nowMinutes < endMinutes;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 42,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          startLabel,
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5C4ED9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          endLabel,
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5C4ED9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 16,
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.courseColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: item.courseColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: item.courseColor,
                          width: 0.8,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.courseCode,
                                  style: textTheme.titleMedium
                                ),
                              ),
                              if (isNow)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5DFFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF6C4DD9),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Now',
                                        style:
                                            textTheme.labelSmall?.copyWith(
                                          color: const Color(0xFF6C4DD9),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                slot.mode == 'Online'
                                    ? Icons.videocam_outlined
                                    : Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  venueLabel,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
