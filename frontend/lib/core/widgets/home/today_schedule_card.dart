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
    this.isAllDay = false,
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

  /// When true (events only), time column shows "All" / "day" instead of a range.
  final bool isAllDay;
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

  static final _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
  );

  static const _timeLabelColor = Color(0xFF5C4ED9);

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

  TextStyle? _timeLabelStyle(TextTheme textTheme) {
    return textTheme.bodyMedium?.copyWith(
      color: _timeLabelColor,
      fontWeight: FontWeight.w600,
    );
  }

  IconData _venueIcon(TodayScheduleItem item) {
    if (item.type == TodayScheduleItemType.classItem && item.isOnline) {
      return Icons.videocam_outlined;
    }
    return Icons.location_on_outlined;
  }

  Widget _scheduleHeader(
    TextTheme textTheme, {
    required bool expandTitle,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    bool showAcademicBreakInHeader = false,
  }) {
    final title = Text(
      "Today's Schedule",
      style: textTheme.titleLarge,
    );
    final showChip =
        showAcademicBreakInHeader && showAcademicBreakChip && academicBreakTitle != null;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (expandTitle) Expanded(child: title) else title,
          if (showChip)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: appPrimarySwatch.shade700.withAlpha(20),
                borderRadius: BorderRadius.circular(999),
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
    );
  }

  Widget _buildItemCard(TextTheme textTheme, TodayScheduleItem item) {
    const warningColor = Colors.orange;
    final isClass = item.type == TodayScheduleItemType.classItem;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.1),
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
                isClass ? Icons.school : Icons.event,
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
          if (isClass && item.overlapsWithEventTitle != null) ...[
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
                  _venueIcon(item),
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
    );
  }

  /// Single "All / day" label; stacks all all-day events on the right.
  Widget _buildAllDayGroup(
    TextTheme textTheme,
    List<TodayScheduleItem> allDayItems,
  ) {
    final timeStyle = _timeLabelStyle(textTheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text('All', style: timeStyle),
                const SizedBox(height: 4),
                Text('day', style: timeStyle),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < allDayItems.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: allDayItems[i].color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildItemCard(textTheme, allDayItems[i]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One row: time range + dot + card (timed items only).
  Widget _buildScheduleItemRow(
    TextTheme textTheme,
    TodayScheduleItem item,
  ) {
    final startLabel = _formatMinutes24h(item.startMinutes);
    final endLabel = _formatMinutes24h(item.endMinutes);
    final timeStyle = _timeLabelStyle(textTheme);

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
                Text(startLabel, style: timeStyle),
                const SizedBox(height: 4),
                Text(endLabel, style: timeStyle),
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
            child: _buildItemCard(textTheme, item),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (items.isEmpty) {
      final isAcademicBreak = academicBreakTitle != null;
      final subtitle = isAcademicBreak
          ? _academicBreakSubtitle(academicBreakTitle!)
          : 'Rest well 😊';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _scheduleHeader(
              textTheme,
              expandTitle: false,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
            ),
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
            const SizedBox(height: 4),
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
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _scheduleHeader(
            textTheme,
            expandTitle: true,
            showAcademicBreakInHeader: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._buildScheduleItemList(textTheme),
        ],
      ),
    );
  }

  List<Widget> _buildScheduleItemList(TextTheme textTheme) {
    final allDayItems = items.where((i) => i.isAllDay).toList(growable: false);
    final timedItems = items.where((i) => !i.isAllDay).toList(growable: false);

    final out = <Widget>[];
    if (allDayItems.isNotEmpty) {
      out.add(_buildAllDayGroup(textTheme, allDayItems));
    }
    for (final item in timedItems) {
      out.add(_buildScheduleItemRow(textTheme, item));
    }
    return out;
  }
}
