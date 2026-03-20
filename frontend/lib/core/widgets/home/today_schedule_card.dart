import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';

enum TodayScheduleItemType {
  classItem,
  eventItem,
}

class TodayScheduleItem {
  const TodayScheduleItem({
    required this.type,
    required this.startMinutes,
    required this.endMinutes,
    required this.title,
    required this.color,
    required this.isOnline,
    this.venueLabel,
    this.overlapsWithEventTitle,
  });

  final TodayScheduleItemType type;
  final int startMinutes;
  final int endMinutes;
  final String title;
  final Color color;

  /// For classes only: whether the mode is online.
  final bool isOnline;

  /// Display label for venue/location.
  final String? venueLabel;

  /// For classes only: label of the first overlapping event.
  final String? overlapsWithEventTitle;
}

class TodayScheduleCard extends StatelessWidget {
  const TodayScheduleCard({
    super.key,
    required this.items,
    this.academicBreakTitle,
    this.showAcademicBreakChip = false,
  });

  final List<TodayScheduleItem> items;
  final String? academicBreakTitle;
  final bool showAcademicBreakChip;

  int _safeMinutes(int minutes) {
    // Handle the "end of day" representation (1440) by showing 23:59.
    if (minutes >= 24 * 60) return 23 * 60 + 59;
    if (minutes < 0) return 0;
    return minutes;
  }

  String _formatMinutes24h(int minutes) {
    final safe = _safeMinutes(minutes);
    final hour = safe ~/ 60;
    final minute = safe % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _academicBreakSubtitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('revision')) return 'Stay focused 📚';
    if (t.contains('exam')) return 'All the best 💪';
    if (t.contains('break')) return 'Enjoy your break 😊';
    return 'No classes today';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const warningColor = Colors.orange;

    if (items.isEmpty) {
      final isAcademicBreak = academicBreakTitle != null;
      final subtitle = isAcademicBreak
          ? _academicBreakSubtitle(academicBreakTitle!)
          : 'Rest well 😊';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/rest.svg',
              height: 120,
            ),
            const SizedBox(height: AppSpacing.md),
            if (!isAcademicBreak)
              Text(
                'No schedule today',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            if (isAcademicBreak) ...[
              const SizedBox(height: 8),
              Text(
                academicBreakTitle!,
                style: textTheme.titleMedium?.copyWith(
                  color: appPrimarySwatch.shade700,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: isAcademicBreak
                    ? appPrimarySwatch.shade700
                    : const Color(0xFF7669E8),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's Schedule",
                  style: textTheme.titleLarge,
                ),
              ),
              if (showAcademicBreakChip && academicBreakTitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: appPrimarySwatch.shade700.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    academicBreakTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: appPrimarySwatch.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) {
            final startLabel = _formatMinutes24h(item.startMinutes);
            final endLabel = _formatMinutes24h(item.endMinutes);

            final venueIcon = item.type == TodayScheduleItemType.classItem
                ? (item.isOnline
                    ? Icons.videocam_outlined
                    : Icons.location_on_outlined)
                : Icons.location_on_outlined;

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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          endLabel,
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5C4ED9),
                            fontWeight: FontWeight.w600,
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
                          color: item.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: item.color,
                          width: 0.8,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                item.type == TodayScheduleItemType.classItem
                                    ? Icons.school
                                    : Icons.event,
                                size: 16,
                                color: item.color,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (item.type == TodayScheduleItemType.classItem &&
                              item.overlapsWithEventTitle != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '⚠ Overlaps with ${item.overlapsWithEventTitle}',
                              style: textTheme.bodySmall?.copyWith(
                                color: warningColor.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (item.venueLabel != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  venueIcon,
                                  size: 16,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.venueLabel!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ]
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
