import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../builders/schedule_appointment_builder.dart';
import '../../constants/app_spacing.dart';
import '../../models/academic_event.dart';
import '../../utils/date_time_format.dart';
import '../../utils/schedule_appointment_details.dart';

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
    final timeLabel = formatWeekdayTimeRange(
      start,
      end,
      dayTimeSeparator: ' • ',
      timeRangeSeparator: ' – ',
    );

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
    final subtitle = formatMonthlyAgendaSubtitle(appointment);
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
}

