import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../builders/schedule_appointment_builder.dart';
import '../../constants/app_spacing.dart';
import '../../constants/weekdays.dart';
import '../../models/academic_event.dart';
import '../../utils/date_time_format.dart';

enum ScheduleDetailsType { classDetails, eventDetails }

class ScheduleDetailsSheet extends StatelessWidget {
  const ScheduleDetailsSheet({
    super.key,
    required this.sheetTitle,
    required this.appointment,
    required this.type,
  });

  final String sheetTitle;
  final Appointment appointment;
  final ScheduleDetailsType type;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.75;

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
                      // TODO: Wire up edit flow when available.
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (type == ScheduleDetailsType.classDetails)
                _buildClassContent(context)
              else
                _buildEventContent(context),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    // TODO: Wire up delete flow when available.
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

  Widget _buildClassContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subjectLines = appointment.subject.split('\n');
    final classTitle = subjectLines.isNotEmpty ? subjectLines[0] : '';
    final classType =
        subjectLines.length > 1 ? subjectLines[1].trim() : null;

    final start = appointment.startTime;
    final end = appointment.endTime;
    final dayLabel = weekdayNamesMondayFirst[start.weekday - 1];
    final timeLabel =
        '$dayLabel • ${formatTime12h(start)} – ${formatTime12h(end)}';

    String? mode;
    String? venue;
    final meta = appointment.id;
    if (meta is ScheduleAppointmentMeta) {
      mode = meta.mode;
      venue = meta.venue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColorTitleRow(
          context: context,
          title: classTitle,
        ),
        if (classType != null && classType.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                classType,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
    );
  }

  Widget _buildEventContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final event = _extractEvent();
    final title = event?.title.trim() ?? appointment.subject.trim();
    final subtitle = _formatEventRange(event);
    final location = event?.location?.trim();
    final hasLocation = location != null && location.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColorTitleRow(
          context: context,
          title: title,
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
    );
  }

  Widget _buildColorTitleRow({
    required BuildContext context,
    required String title,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
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
    );
  }

  AcademicEvent? _extractEvent() {
    final meta = appointment.id;
    if (meta is ScheduleAppointmentMeta &&
        meta.type == ScheduleAppointmentMeta.typeEvent &&
        meta.events.isNotEmpty) {
      return meta.events.first;
    }
    return null;
  }

  String _formatEventRange(AcademicEvent? event) {
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

