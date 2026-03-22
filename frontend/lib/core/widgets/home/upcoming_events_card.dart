import 'package:flutter/material.dart';

import '../../builders/schedule_appointment_builder.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../models/academic_event.dart';
import '../../utils/date_time_format.dart';
import '../../utils/schedule_event_appointment_actions.dart';
import '../../utils/term_windows.dart';
import '../schedule/schedule_appointments_bottom_sheet.dart';
import '../../../screens/add/add_new_screen.dart' show AddType;
import '../common/empty_state_card.dart';

class UpcomingEventsCard extends StatefulWidget {
  const UpcomingEventsCard({
    super.key,
    required this.events,
    required this.selectedTerm,
  });

  final List<AcademicEvent> events;
  final TermWindow selectedTerm;

  @override
  State<UpcomingEventsCard> createState() => _UpcomingEventsCardState();
}

class _UpcomingEventsCardState extends State<UpcomingEventsCard> {
  bool _expanded = false;

  static const _tooltipMessage =
      'Events starting in the next 7 days (after today).';

  String _eventSubtitle(AcademicEvent event) {
    final startDay = DateTime(
      event.startDateTime.year,
      event.startDateTime.month,
      event.startDateTime.day,
    );
    final endDay = DateTime(
      event.endDateTime.year,
      event.endDateTime.month,
      event.endDateTime.day,
    );
    final sameDay =
        startDay.year == endDay.year &&
        startDay.month == endDay.month &&
        startDay.day == endDay.day;

    if (event.allDay) {
      if (sameDay) return '${formatRelativeDueDate(startDay)} (All day)';
      return formatDateRangeDdMmYyyy(startDay, endDay);
    }
    if (sameDay) {
      return '${formatRelativeDueDate(startDay)}, ${formatTimeRange12h(event.startDateTime, event.endDateTime)}';
    }
    return formatDateTimeRangeDdMmYyyy(
      event.startDateTime,
      event.endDateTime,
    );
  }

  Future<void> _openMultiEventSheet() async {
    final events = widget.events;
    if (events.isEmpty) return;
    final appointments = events
        .take(5)
        .map(ScheduleAppointmentBuilder.appointmentForEventDetail)
        .toList(growable: false);
    await showScheduleAppointmentsBottomSheet(
      context: context,
      appointments: appointments,
      onEditAppointment: (a) => scheduleEventAppointmentEdit(
        context,
        a,
        selectedTerm: widget.selectedTerm,
      ),
      onCancelAppointment: (a) => scheduleEventAppointmentDelete(context, a),
    );
  }

  Future<void> _openSingleEventSheet(AcademicEvent event) async {
    final appointment =
        ScheduleAppointmentBuilder.appointmentForEventDetail(event);
    await showScheduleAppointmentsBottomSheet(
      context: context,
      appointments: [appointment],
      onEditAppointment: (a) => scheduleEventAppointmentEdit(
        context,
        a,
        selectedTerm: widget.selectedTerm,
      ),
      onCancelAppointment: (a) => scheduleEventAppointmentDelete(context, a),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final events = widget.events;
    final hasMany = events.length > 5;
    final visible =
        !_expanded && hasMany ? events.take(5).toList(growable: false) : events;

    if (events.isEmpty) {
      return EmptyStateCard(
        icon: Icons.event_available,
        title: 'Upcoming Events',
        subtitle: 'No upcoming events yet.',
        buttonText: 'Add event',
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.addNew,
            arguments: AddType.event,
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _openMultiEventSheet,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Upcoming Events',
                            style: textTheme.titleLarge,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: _tooltipMessage,
                        child: Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasMany)
                  TextButton(
                    onPressed: () {
                      setState(() => _expanded = !_expanded);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_expanded ? 'Show less' : 'Show All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...visible.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onTap: () => _openSingleEventSheet(event),
                    leading: const Icon(Icons.event, size: 20),
                    title: Text(
                      event.title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _eventSubtitle(event),
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (i < visible.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE5E5E5),
                    ),
                ],
              );
            }),
            if (hasMany && !_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+${events.length - 5} more',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
