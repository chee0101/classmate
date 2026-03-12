import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../core/builders/schedule_appointment_builder.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/months.dart';
import '../../core/constants/weekdays.dart';
import '../../core/models/academic_event.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/course.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/services/academic_event_store.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/utils/session_term_resolver.dart';
import '../../core/models/session_term_ref.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/common/session_term_context_label.dart';
import '../../core/widgets/schedule/schedule_class_appointment_text.dart';
import '../../core/widgets/schedule/schedule_mode_toggle.dart';
import '../../core/widgets/schedule/class_details_sheet.dart';
import '../../core/widgets/schedule/event_details_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _showMonthly = false;
  final CalendarController _calendarController = CalendarController();
  DateTime _visibleDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _calendarController.view = CalendarView.week;
    _calendarController.displayDate = _visibleDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder<List<AcademicSession>>(
        valueListenable: academicSessionsNotifier,
        builder: (context, sessionsList, _) {
          final activeSession = currentAcademicSessionNotifier.value;
          final sessions = <AcademicSession>[...sessionsList];
          if (activeSession != null &&
              !sessions.any((s) => s.id == activeSession.id)) {
            sessions.add(activeSession);
          }

          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyStateCard(
                  onPressed: () {
                    AcademicSessionSetupBottomSheet.show(context);
                  },
                ),
              ),
            );
          }

          final now = DateTime.now();
          final refs = buildAllSessionTermRefs(sessions);
          final defaultRef = resolveDefaultSessionTermRef(refs, now);

          return ValueListenableBuilder<SessionTermSelection?>(
            valueListenable: selectedSessionTermNotifier,
            builder: (context, selectedSelection, _) {
              final selectedSessionId =
                  selectedSelection?.sessionId ?? defaultRef.session.id;
              final selectedTermId =
                  selectedSelection?.termId ?? defaultRef.term.id;

              // Resolve exact ref from current selection, falling back to defaultRef.
              SessionTermRef selectedRef = defaultRef;
              for (final ref in refs) {
                if (ref.session.id == selectedSessionId &&
                    ref.term.id == selectedTermId) {
                  selectedRef = ref;
                  break;
                }
              }

              final selectedSession = selectedRef.session;
              final selectedTerm = selectedRef.term;
              if (selectedSelection == null ||
                  selectedSelection.sessionId != selectedSession.id ||
                  selectedSelection.termId != selectedTerm.id) {
                setSelectedSessionTerm(
                  sessionId: selectedSession.id,
                  termId: selectedTerm.id,
                );
              }

              return ValueListenableBuilder<List<TimetableEntry>>(
                valueListenable: timetablesNotifier,
                builder: (context, entries, _) {
                  return ValueListenableBuilder<List<Course>>(
                    valueListenable: coursesNotifier,
                    builder: (context, courses, _) {
                      return ValueListenableBuilder<List<AcademicEvent>>(
                        valueListenable: academicEventsNotifier,
                        builder: (context, events, _) {
                          final filteredEntries = entries
                              .where(
                                (e) =>
                                    e.sessionId == selectedSession.id &&
                                    e.termId == selectedTerm.id,
                              )
                              .toList(growable: false);

                          final courseColorByCode = <String, Color>{
                            for (final c in courses.where(
                              (c) =>
                                  c.sessionId == selectedSession.id &&
                                  c.termId == selectedTerm.id,
                            ))
                              c.courseCode: ScheduleAppointmentBuilder.parseHexColor(c.courseColor),
                          };

                          final selectedTermEvents = events
                              .where(
                                (event) =>
                                    event.sessionId == selectedSession.id &&
                                    event.termId == selectedTerm.id,
                              )
                              .toList(growable: false);
                          final appointments = ScheduleAppointmentBuilder.build(
                            entries: filteredEntries,
                            courseColorByCode: courseColorByCode,
                            events: selectedTermEvents,
                            term: selectedTerm,
                            forMonthlyAgenda: _showMonthly,
                            contentFilter: ScheduleContentFilter.both,
                          );

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                                child: SessionTermContextLabel(
                                  sessionName: selectedSession.name,
                                  termLabel: selectedTerm.label,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                child: ScheduleModeToggle(
                                  showMonthly: _showMonthly,
                                  onChanged: (monthly) {
                                    setState(() {
                                      _showMonthly = monthly;
                                      _calendarController.view = monthly
                                          ? CalendarView.month
                                          : CalendarView.week;
                                      _calendarController.displayDate = _visibleDate;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    AppSpacing.md,
                                    0,
                                    AppSpacing.md,
                                    AppSpacing.md,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SfCalendar(
                                      controller: _calendarController,
                                      view: _showMonthly
                                          ? CalendarView.month
                                          : CalendarView.week,
                                      backgroundColor: Colors.white,
                                      dataSource: _ScheduleDataSource(appointments),
                                      firstDayOfWeek: 1,
                                      headerHeight: 40,
                                      headerStyle: const CalendarHeaderStyle(
                                        textStyle: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        backgroundColor: Color(0xFF6E52D9),
                                      ),
                                      showNavigationArrow: true,
                                      viewHeaderHeight: _showMonthly ? 40 : 58,
                                      viewHeaderStyle: const ViewHeaderStyle(
                                        backgroundColor: Color(0xFFE2E4FD),
                                      ),
                                      showDatePickerButton: true,
                                      showCurrentTimeIndicator: true,
                                      selectionDecoration: const BoxDecoration(
                                        color: Colors.transparent,
                                      ),
                                      onViewChanged: (details) {
                                        if (details.visibleDates.isEmpty) return;
                                        final middle =
                                            details.visibleDates[details.visibleDates.length ~/ 2];
                                        if (!mounted || _visibleDate == middle) return;
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (!mounted || _visibleDate == middle) return;
                                          setState(() {
                                            _visibleDate = middle;
                                          });
                                        });
                                      },
                                      monthViewSettings: const MonthViewSettings(
                                        appointmentDisplayMode:
                                            MonthAppointmentDisplayMode.indicator,
                                        showAgenda: true,
                                        agendaItemHeight: 44,
                                        agendaStyle: AgendaStyle(
                                          backgroundColor: Color(0xFFE2E4FD),
                                        ),
                                      ),
                                      timeSlotViewSettings: const TimeSlotViewSettings(
                                        startHour: 0,
                                        endHour: 24,
                                        timeIntervalHeight: 64,
                                      ),
                                      appointmentBuilder:
                                          (context, calendarAppointmentDetails) {
                                      final appointment =
                                          calendarAppointmentDetails
                                              .appointments
                                              .first as Appointment;
                                      if (_showMonthly) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                            vertical: 1,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          decoration: BoxDecoration(
                                            color: appointment.color
                                                .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: appointment.color
                                                  .withValues(alpha: 0.45),
                                              width: 0.7,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                appointment.subject,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  height: 1.0,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatMonthlyAgendaSubtitle(
                                                  appointment,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  height: 1.0,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      final maxAppointmentLines =
                                          appointment.isAllDay ? 1 : 3;
                                      return Container(
                                        padding: const EdgeInsets.all(3),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: appointment.color
                                              .withValues(alpha: 0.26),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: appointment.notes == ScheduleAppointmentMeta.typeClass
                                            ? ScheduleClassAppointmentText(
                                                subject: appointment.subject,
                                                textColor: appointment.color,
                                                maxLines: maxAppointmentLines,
                                              )
                                            : Text(
                                                appointment.subject,
                                                maxLines: maxAppointmentLines,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                        color: AppPrimarySwatch.shade900,
                                                    ),
                                              ),
                                      );
                                    },
                                      onTap: (details) {
                                         // In monthly view, don't open details when tapping the grid/date cells.
                                         // Only taps on items that carry appointments (e.g., agenda blocks)
                                         // should open the bottom sheet.
                                         if (_showMonthly &&
                                             details.targetElement ==
                                                 CalendarElement.calendarCell) {
                                           return;
                                         }
                                        final rawAppointments = details.appointments;
                                        if (rawAppointments == null ||
                                            rawAppointments.isEmpty ||
                                            !mounted) {
                                          return;
                                        }

                                        final appointments = rawAppointments
                                            .whereType<Appointment>()
                                            .toList(growable: false);
                                        if (appointments.isEmpty) return;
                                        final detailAppointments =
                                            _expandAppointmentsForDetails(appointments);
                                        if (detailAppointments.isEmpty) return;
                                        _showAppointmentsBottomSheet(detailAppointments);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                             ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatMonthlyAgendaSubtitle(Appointment appointment) {
    final meta = appointment.id;
    if (meta is ScheduleAppointmentMeta &&
        meta.type == ScheduleAppointmentMeta.typeEvent &&
        meta.events.isNotEmpty) {
      final event = meta.events.first;
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
    return _formatAppointmentRange(appointment);
  }

  void _showAppointmentsBottomSheet(List<Appointment> appointments) {
    final first = appointments.first;
    final isClassDetails = first.notes == ScheduleAppointmentMeta.typeClass;
    final sheetTitle = appointments.length == 1
        ? (isClassDetails ? 'Class Details' : 'Event Details')
        : 'Details';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.75;
        final isSingleClassDetails =
            appointments.length == 1 && isClassDetails;
        final isSingleEventDetails =
            appointments.length == 1 && !isClassDetails;

        if (isSingleClassDetails) {
          final appointment = appointments.first;
          return ClassDetailsSheet(
            sheetTitle: sheetTitle,
            appointment: appointment,
          );
        }

        if (isSingleEventDetails) {
          final appointment = appointments.first;
          return EventDetailsSheet(
            sheetTitle: sheetTitle,
            appointment: appointment,
          );
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
                  Text(
                    sheetTitle,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        final appointment = appointments[index];
                        final meta = appointment.id;
                        String? eventLocation;
                        if (meta is ScheduleAppointmentMeta &&
                            meta.type == ScheduleAppointmentMeta.typeEvent &&
                            meta.events.isNotEmpty) {
                          eventLocation = meta.events.first.location?.trim();
                          if (eventLocation != null && eventLocation.isEmpty) {
                            eventLocation = null;
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: appointment.color,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appointment.subject,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatAppointmentRange(appointment),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    if (eventLocation != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '📍 $eventLocation',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Appointment> _expandAppointmentsForDetails(List<Appointment> appointments) {
    final output = <Appointment>[];
    for (final appointment in appointments) {
      final meta = appointment.id;
      if (meta is! ScheduleAppointmentMeta) {
        output.add(appointment);
        continue;
      }

      if (meta.type == ScheduleAppointmentMeta.typeEventOverflow) {
        for (final event in meta.events) {
          output.add(
            Appointment(
              startTime: event.startDateTime,
              endTime: event.endDateTime,
              subject: event.title,
              color: AppPrimarySwatch.shade700,
              isAllDay: event.allDay || !isSameDate(event.startDateTime, event.endDateTime),
              notes: ScheduleAppointmentMeta.typeEvent,
              id: ScheduleAppointmentMeta(
                type: ScheduleAppointmentMeta.typeEvent,
                events: [event],
              ),
            ),
          );
        }
        continue;
      }

      if (meta.type == ScheduleAppointmentMeta.typeEvent && meta.events.isNotEmpty) {
        final event = meta.events.first;
        output.add(
          Appointment(
            startTime: event.startDateTime,
            endTime: event.endDateTime,
            subject: event.title,
            color: appointment.color,
            isAllDay: event.allDay || !isSameDate(event.startDateTime, event.endDateTime),
            notes: ScheduleAppointmentMeta.typeEvent,
            id: ScheduleAppointmentMeta(
              type: ScheduleAppointmentMeta.typeEvent,
              events: [event],
            ),
          ),
        );
        continue;
      }

      output.add(appointment);
    }
    return output;
  }

  String _formatAppointmentRange(Appointment appointment) {
    final meta = appointment.id;
    if (appointment.notes == ScheduleAppointmentMeta.typeClass) {
      final start = appointment.startTime;
      final end = appointment.endTime;
      final dayLabel = weekdayNamesMondayFirst[start.weekday - 1];
      return '$dayLabel ${formatTime12h(start)} - ${formatTime12h(end)}';
    }
    if (meta is ScheduleAppointmentMeta &&
        meta.type == ScheduleAppointmentMeta.typeEvent &&
        meta.events.isNotEmpty) {
      final event = meta.events.first;
      final start = event.startDateTime;
      final end = event.endDateTime;
      if (event.allDay) {
        return formatAllDayRange(start, end);
      }
      return formatDateTimeRange(start, end);
    }

    if (appointment.isAllDay) {
      final start = appointment.startTime;
      final end = appointment.endTime;
      final sameDay =
          start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;
      if (sameDay) {
        return '${start.day} ${monthShortLabel(start.month)} ${start.year} (All day)';
      }
      return '${start.day} ${monthShortLabel(start.month)} - ${end.day} ${monthShortLabel(end.month)} (All day)';
    }

    final start = appointment.startTime;
    final end = appointment.endTime;
    final sameDay =
        start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) {
      return '${start.day} ${monthShortLabel(start.month)} ${formatTime12h(start)} - ${formatTime12h(end)}';
    }
    return '${start.day} ${monthShortLabel(start.month)} ${formatTime12h(start)} - ${end.day} ${monthShortLabel(end.month)} ${formatTime12h(end)}';
  }
}

class _ScheduleDataSource extends CalendarDataSource {
  _ScheduleDataSource(List<Appointment> source) {
    appointments = source;
  }
}
