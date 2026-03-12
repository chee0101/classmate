import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../constants/app_spacing.dart';
import '../../utils/date_time_format.dart';
import '../../builders/schedule_appointment_builder.dart';
import '../../models/academic_event.dart';

class EventDetailsSheet extends StatelessWidget {
  const EventDetailsSheet({
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

    final eventMeta = appointment.id;
    AcademicEvent? event;
    if (eventMeta is ScheduleAppointmentMeta &&
        eventMeta.type == ScheduleAppointmentMeta.typeEvent &&
        eventMeta.events.isNotEmpty) {
      event = eventMeta.events.first;
    }

    final title = event?.title.trim() ?? appointment.subject.trim();
    final subtitle = _formatAppointmentRangeForEvent(appointment, event);
    final location = event?.location?.trim();
    final hasLocation = location != null && location.isNotEmpty;

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
                      // TODO: Wire up event edit flow when available.
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
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (hasLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        '📍 $location',
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
                    // TODO: Wire up event delete flow when available.
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

  String _formatAppointmentRangeForEvent(
    Appointment appointment,
    AcademicEvent? event,
  ) {
    if (event != null) {
      if (event.allDay) {
        if (isSameDate(event.startDateTime, event.endDateTime)) {
          return 'All day';
        }
        return formatAllDayRange(event.startDateTime, event.endDateTime);
      }
      if (isSameDate(event.startDateTime, event.endDateTime)) {
        return '${formatTime12h(event.startDateTime)} - ${formatTime12h(event.endDateTime)}';
      }
      return formatDateTimeRange(event.startDateTime, event.endDateTime);
    }

    if (!appointment.isAllDay &&
        isSameDate(appointment.startTime, appointment.endTime)) {
      return '${formatTime12h(appointment.startTime)} - ${formatTime12h(appointment.endTime)}';
    }
    return formatDateTimeRange(appointment.startTime, appointment.endTime);
  }
}

