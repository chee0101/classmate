import 'package:flutter/material.dart';

import '../common/empty_state_card.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../../screens/add/add_new_screen.dart' show AddType;
import '../../models/timetable_entry.dart';
import '../../utils/date_time_format.dart';
import 'package:flutter_svg/svg.dart';

class TodayClassItem {
  const TodayClassItem({
    required this.slot,
    required this.courseCode,
    required this.courseColor,
    this.partiallyAffected = false,
  });

  final TimetableSlot slot;
  final String courseCode;
  final Color courseColor;
  final bool partiallyAffected;
}

/// A card widget that displays today's classes or an empty state.
class TodayClassesCard extends StatelessWidget {
  const TodayClassesCard({
    super.key,
    required this.items,
    this.bannerTitle,
    this.bannerSubtitle,
    this.emptySubtitleOverride,
    this.showAcademicBreakMessage = false,
    this.academicBreakTitle,
  });

  final List<TodayClassItem> items;
  final String? bannerTitle;
  final String? bannerSubtitle;
  final String? emptySubtitleOverride;
  final bool showAcademicBreakMessage;
  final String? academicBreakTitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const purple = Color(0xFF6C4DD9);

    String _formatTime24h(String label) {
      final minutes = parseTimeLabel12hToMinutes(label);
      if (minutes == null) return label;
      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }

    if (items.isEmpty) {
      if (showAcademicBreakMessage) {
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
              const SizedBox(height: AppSpacing.md),

              /// CENTERED EMPTY STATE
              Center(
                child: Column(
                  children: [
                    /// SVG Illustration
                    SvgPicture.asset(
                      academicBreakTitle!.contains('Exam') || academicBreakTitle!.contains('Revision') ? 'assets/images/exam.svg' : 'assets/images/rest.svg',
                      height: 90,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    /// Break Title
                    if (academicBreakTitle != null) ...[
                      Text(
                        academicBreakTitle!,
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: purple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],

                    /// Subtitle
                    Text(
                      'No classes today',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return EmptyStateCard(
        icon: Icons.event_busy,
        title: "Today's Classes",
        subtitle: emptySubtitleOverride ?? 'No timetable added yet.',
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
          if (bannerTitle != null || bannerSubtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bannerTitle != null)
                    Text(
                      bannerTitle!,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (bannerSubtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      bannerSubtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
                                  style: textTheme.titleMedium,
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
                                        style: textTheme.labelSmall?.copyWith(
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
                          if (item.partiallyAffected) ...[
                            const SizedBox(height: 6),
                            Text(
                              '⚠ Partially affected by event',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
