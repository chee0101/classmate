import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../constants/app_spacing.dart';

Future<Appointment?> showScheduleOverflowPopupMenu({
  required BuildContext context,
  required Offset? tapPosition,
  required List<Appointment> hiddenItems,
  required String Function(Appointment appointment) formatAppointmentRange,
}) {
  return showMenu<Appointment>(
    context: context,
    position: _buildOverflowMenuPosition(
      context: context,
      tapPosition: tapPosition,
    ),
    elevation: 12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    constraints: const BoxConstraints(maxWidth: 340, maxHeight: 360),
    items: hiddenItems.map((item) {
      return PopupMenuItem<Appointment>(
        value: item,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatAppointmentRange(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList(growable: false),
  );
}

RelativeRect _buildOverflowMenuPosition({
  required BuildContext context,
  required Offset? tapPosition,
}) {
  final overlay = Overlay.of(context).context.findRenderObject();
  final screenSize = MediaQuery.sizeOf(context);
  final fallbackPoint = Offset(screenSize.width / 2, screenSize.height * 0.3);
  final anchor = tapPosition ?? fallbackPoint;
  const popupMaxWidth = 340.0;
  const popupMaxHeight = 360.0;
  const edgePadding = 12.0;
  double safeClamp(double value, double min, double max) {
    if (!value.isFinite) return min;
    if (!min.isFinite || !max.isFinite) return value;
    if (max < min) return min;
    return value.clamp(min, max).toDouble();
  }

  if (overlay is! RenderBox) {
    final maxDx = (screenSize.width - popupMaxWidth - edgePadding).toDouble();
    final maxDy = (screenSize.height - popupMaxHeight - edgePadding).toDouble();
    final dx = safeClamp(
      anchor.dx,
      edgePadding,
      maxDx,
    );
    final dy = safeClamp(
      anchor.dy,
      edgePadding,
      maxDy,
    );
    return RelativeRect.fromLTRB(
      dx,
      dy,
      screenSize.width - dx,
      screenSize.height - dy,
    );
  }

  final localInOverlay = overlay.globalToLocal(anchor);
  final maxDx = (overlay.size.width - popupMaxWidth - edgePadding).toDouble();
  final maxDy = (overlay.size.height - popupMaxHeight - edgePadding).toDouble();
  final dx = safeClamp(
    localInOverlay.dx,
    edgePadding,
    maxDx,
  );
  final dy = safeClamp(
    localInOverlay.dy,
    edgePadding,
    maxDy,
  );
  return RelativeRect.fromLTRB(
    dx,
    dy,
    overlay.size.width - dx,
    overlay.size.height - dy,
  );
}
