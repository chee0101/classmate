import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../constants/app_spacing.dart';
import '../../constants/weekdays.dart';
import '../../utils/date_time_format.dart';
import '../../builders/schedule_appointment_builder.dart';

class ClassDetailsSheet extends StatelessWidget {
  const ClassDetailsSheet({
    super.key,
    required this.sheetTitle,
    required this.appointment,
  });

  final String sheetTitle;
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.75;

    final subjectLines = appointment.subject.split('\n');
    final classTitle = subjectLines.isNotEmpty ? subjectLines[0] : '';
    final classType =
        subjectLines.length > 1 ? subjectLines[1].trim() : null;

    final start = appointment.startTime;
    final end = appointment.endTime;
    final dayLabel = weekdayNamesMondayFirst[start.weekday - 1];
    final timeLabel =
        '$dayLabel • ${formatTime12h(start)} – ${formatTime12h(end)}';

    // Extract mode and venue from appointment meta
    String? mode;
    String? venue;
    final meta = appointment.id;
    if (meta is ScheduleAppointmentMeta) {
      mode = meta.mode;
      venue = meta.venue;
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sheetTitle,
                      style: textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      // TODO: Wire up class edit flow when available.
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 24,
                        decoration: BoxDecoration(
                          color: appointment.color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          classTitle,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (classType != null && classType.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.sm,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          classType,
                          style: textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    timeLabel,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (mode != null && mode.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        mode.toLowerCase() == 'online'
                            ? '💻 Online'
                            : venue != null && venue.isNotEmpty
                                ? '📍 $venue'
                                : '📍 Physical',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    // TODO: Wire up class delete flow when available.
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

