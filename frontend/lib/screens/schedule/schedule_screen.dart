import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/months.dart';
import '../../core/constants/weekdays.dart';
import '../../core/models/academic_event.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/class_type.dart';
import '../../core/models/course.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/services/academic_event_store.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/animated_segmented_switch.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/common/session_term_context_label.dart';

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

          final refs = <({AcademicSession session, TermWindow term})>[];
          for (final session in sessions) {
            for (final term in buildTermWindows(session)) {
              refs.add((session: session, term: term));
            }
          }

          var selectedRef = refs.first;
          final now = DateTime.now();
          final current = refs.where(
            (ref) =>
                !now.isBefore(ref.term.start) && !now.isAfter(ref.term.end),
          );
          if (current.isNotEmpty) selectedRef = current.first;

          return ValueListenableBuilder<SessionTermSelection?>(
            valueListenable: selectedSessionTermNotifier,
            builder: (context, selectedSelection, _) {
              final selectedSessionId =
                  selectedSelection?.sessionId ?? selectedRef.session.id;
              final selectedTermId =
                  selectedSelection?.termId ?? selectedRef.term.id;
              final exact = refs.where(
                (ref) =>
                    ref.session.id == selectedSessionId &&
                    ref.term.id == selectedTermId,
              );
              if (exact.isNotEmpty) selectedRef = exact.first;

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
                              c.courseCode: _parseHexColor(c.courseColor),
                          };

                          final classSlots =
                              _flattenSlots(filteredEntries, courseColorByCode);
                          final selectedTermEvents = events
                              .where(
                                (event) =>
                                    event.sessionId == selectedSession.id &&
                                    event.termId == selectedTerm.id,
                              )
                              .toList(growable: false);
                          final appointments = _buildAppointments(
                            classSlots: classSlots,
                            events: selectedTermEvents,
                            term: selectedTerm,
                            forMonthlyAgenda: _showMonthly,
                          );
                          final headerDate =
                              _calendarController.displayDate ?? _visibleDate;
                          final headerLabel =
                              '${monthShortLabel(headerDate.month)} ${headerDate.year}';

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
                                child: _ScheduleModeToggle(
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
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: () {
                                        _calendarController.backward!();
                                      },
                                    ),
                                    Expanded(
                                      child: Text(
                                        headerLabel,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: () {
                                        _calendarController.forward!();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                  child: SfCalendar(
                                    controller: _calendarController,
                                    view: _showMonthly
                                        ? CalendarView.month
                                        : CalendarView.week,
                                    backgroundColor: Colors.white,
                                    dataSource: _ScheduleDataSource(appointments),
                                    firstDayOfWeek: 1,
                                    headerHeight: 0,
                                    viewHeaderHeight: _showMonthly ? 40 : 54,
                                    viewHeaderStyle: const ViewHeaderStyle(
                                      backgroundColor: Color(0xFFEFF1FE),
                                    ),
                                    showDatePickerButton: false,
                                    showCurrentTimeIndicator: true,
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
                                        backgroundColor: Color(0xFFEFF1FE),
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
                                        child: appointment.notes == 'class'
                                            ? _buildClassAppointmentText(
                                                context,
                                                appointment.subject,
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
                                      if (_showMonthly) return;
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

  List<_RenderedClassSlot> _flattenSlots(
    List<TimetableEntry> entries,
    Map<String, Color> courseColorByCode,
  ) {
    final output = <_RenderedClassSlot>[];
    for (final entry in entries) {
      final color = courseColorByCode[entry.courseCode] ?? const Color(0xFF6C4DD9);
      for (final slot in entry.slots) {
        final dayIndex = weekdayIndexFromString(slot.day);
        if (dayIndex == -1) continue;
        final start = _parseMinutes(slot.startTime);
        final end = _parseMinutes(slot.endTime);
        if (start == null || end == null || end <= start) continue;
        output.add(
          _RenderedClassSlot(
            courseCode: entry.courseCode,
            dayIndex: dayIndex,
            startMinutes: start,
            endMinutes: end,
            color: color,
            classType: slot.classType,
          ),
        );
      }
    }
    return output;
  }

  int? _parseMinutes(String value) {
    final regex =
        RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = regex.firstMatch(value.trim());
    if (match == null) return null;
    final hour12 = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final period = (match.group(3) ?? '').toUpperCase();
    if (hour12 == null || minute == null) return null;
    final hour24 = period == 'AM' ? hour12 % 12 : (hour12 % 12) + 12;
    return hour24 * 60 + minute;
  }

  Color _parseHexColor(String colorHex) {
    final parsed = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
    return Color(parsed ?? 0xFF6C4DD9);
  }

  List<Appointment> _buildAppointments({
    required List<_RenderedClassSlot> classSlots,
    required List<AcademicEvent> events,
    required TermWindow term,
    required bool forMonthlyAgenda,
  }) {
    final appointments = <Appointment>[];

    // Expand recurring class slots into actual dates inside selected term.
    for (final slot in classSlots) {
      for (var date = DateTime(term.start.year, term.start.month, term.start.day);
          !date.isAfter(term.end);
          date = date.add(const Duration(days: 1))) {
        if ((date.weekday - 1) != slot.dayIndex) continue;
        final start = DateTime(
          date.year,
          date.month,
          date.day,
          slot.startMinutes ~/ 60,
          slot.startMinutes % 60,
        );
        final end = DateTime(
          date.year,
          date.month,
          date.day,
          slot.endMinutes ~/ 60,
          slot.endMinutes % 60,
        );
        if (!end.isAfter(start)) continue;
        appointments.add(
          Appointment(
            startTime: start,
            endTime: end,
            subject: '${slot.courseCode}\n${slot.classType.label}',
            color: slot.color,
            isAllDay: false,
            notes: 'class',
            id: const _AppointmentMeta(type: 'class'),
          ),
        );
      }
    }

    final allDayEvents = events
        .where(
          (e) => e.allDay || !_isSameDate(e.startDateTime, e.endDateTime),
        )
        .toList(growable: false);
    final timedEvents = events
        .where(
          (e) => !e.allDay && _isSameDate(e.startDateTime, e.endDateTime),
        )
        .toList(growable: false);

    if (forMonthlyAgenda) {
      final sortedEvents = [...events]
        ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      for (final event in sortedEvents) {
        appointments.add(
          Appointment(
            startTime: event.startDateTime,
            endTime: event.endDateTime,
            subject: event.title,
            color: AppPrimarySwatch.shade700,
            isAllDay: event.allDay,
            notes: 'event',
            id: _AppointmentMeta(type: 'event', events: [event]),
          ),
        );
      }
      return appointments;
    }

    // All-day lane: cap to 2 rows per day (A,B) or (A,+X).
    final allDayByDate = <DateTime, List<AcademicEvent>>{};
    for (final event in allDayEvents) {
      var current = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      final end = DateTime(
        event.endDateTime.year,
        event.endDateTime.month,
        event.endDateTime.day,
      );
      while (!current.isAfter(end)) {
        allDayByDate.putIfAbsent(current, () => <AcademicEvent>[]).add(event);
        current = current.add(const Duration(days: 1));
      }
    }

    final allDayDates = allDayByDate.keys.toList(growable: false)
      ..sort((a, b) => a.compareTo(b));
    for (final date in allDayDates) {
      final dayEvents = [...?allDayByDate[date]]
        ..sort((a, b) => a.title.compareTo(b.title));
      if (dayEvents.isEmpty) continue;

      final dayStart = DateTime(date.year, date.month, date.day, 0, 0);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59);
      final firstEvent = dayEvents.first;
      appointments.add(
        Appointment(
          startTime: dayStart,
          endTime: dayEnd,
          subject: firstEvent.title,
          color: AppPrimarySwatch.shade700,
          isAllDay: true,
          notes: 'event',
          id: _AppointmentMeta(type: 'event', events: [firstEvent]),
        ),
      );
      if (dayEvents.length == 2) {
        final secondEvent = dayEvents[1];
        appointments.add(
          Appointment(
            startTime: dayStart,
            endTime: dayEnd,
            subject: secondEvent.title,
            color: AppPrimarySwatch.shade700,
            isAllDay: true,
            notes: 'event',
            id: _AppointmentMeta(type: 'event', events: [secondEvent]),
          ),
        );
      } else if (dayEvents.length > 2) {
        final hiddenEvents = dayEvents.skip(1).toList(growable: false);
        appointments.add(
          Appointment(
            startTime: dayStart,
            endTime: dayEnd,
            subject: '+${dayEvents.length - 1}',
            color: AppPrimarySwatch.shade800,
            isAllDay: true,
            notes: 'event-overflow',
            id: _AppointmentMeta(type: 'event-overflow', events: hiddenEvents),
          ),
        );
      }
    }

    // Timed events: keep overlap collapsing by exact time range.
    final groupedTimedEvents = <String, List<AcademicEvent>>{};
    for (final event in timedEvents) {
      final key =
          '${event.startDateTime.millisecondsSinceEpoch}|${event.endDateTime.millisecondsSinceEpoch}';
      groupedTimedEvents.putIfAbsent(key, () => <AcademicEvent>[]).add(event);
    }
    for (final group in groupedTimedEvents.values) {
      group.sort((a, b) => a.title.compareTo(b.title));
      if (group.length <= 2) {
        for (final event in group) {
          appointments.add(
            Appointment(
              startTime: event.startDateTime,
              endTime: event.endDateTime,
              subject: event.title,
              color: AppPrimarySwatch.shade700,
              isAllDay: false,
              notes: 'event',
              id: _AppointmentMeta(type: 'event', events: [event]),
            ),
          );
        }
        continue;
      }

      final leadEvent = group.first;
      appointments.add(
        Appointment(
          startTime: leadEvent.startDateTime,
          endTime: leadEvent.endDateTime,
          subject: leadEvent.title,
          color: AppPrimarySwatch.shade700,
          isAllDay: false,
          notes: 'event',
          id: _AppointmentMeta(type: 'event', events: [leadEvent]),
        ),
      );
      appointments.add(
        Appointment(
          startTime: leadEvent.startDateTime,
          endTime: leadEvent.endDateTime,
          subject: '+${group.length - 1}',
          color: AppPrimarySwatch.shade800,
          isAllDay: false,
          notes: 'event-overflow',
          id: _AppointmentMeta(
            type: 'event-overflow',
            events: group.skip(1).toList(growable: false),
          ),
        ),
      );
    }

    return appointments;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  String _formatMonthlyAgendaSubtitle(Appointment appointment) {
    final meta = appointment.id;
    if (meta is _AppointmentMeta &&
        meta.type == 'event' &&
        meta.events.isNotEmpty) {
      final event = meta.events.first;
      if (event.allDay) {
        if (_isSameDate(event.startDateTime, event.endDateTime)) {
          return 'All day';
        }
        return '${event.startDateTime.day} ${monthShortLabel(event.startDateTime.month)} ${event.startDateTime.year} - ${event.endDateTime.day} ${monthShortLabel(event.endDateTime.month)} ${event.endDateTime.year} (All day)';
      }
      if (_isSameDate(event.startDateTime, event.endDateTime)) {
        return '${_formatTime(event.startDateTime)} - ${_formatTime(event.endDateTime)}';
      }
      return '${event.startDateTime.day} ${monthShortLabel(event.startDateTime.month)} ${event.startDateTime.year} ${_formatTime(event.startDateTime)} - ${event.endDateTime.day} ${monthShortLabel(event.endDateTime.month)} ${event.endDateTime.year} ${_formatTime(event.endDateTime)}';
    }
    if (!appointment.isAllDay &&
        _isSameDate(appointment.startTime, appointment.endTime)) {
      return '${_formatTime(appointment.startTime)} - ${_formatTime(appointment.endTime)}';
    }
    return _formatAppointmentRange(appointment);
  }

  Widget _buildClassAppointmentText(
    BuildContext context,
    String subject, {
    required Color textColor,
    required int maxLines,
  }) {
    final parts = subject.split('\n');
    final courseCode = parts.isNotEmpty ? parts.first : subject;
    final classType = parts.length > 1 ? parts.sublist(1).join('\n') : '';
    final resolvedTextColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.28),
      textColor,
    );
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: resolvedTextColor,
        );
    return RichText(
      maxLines: maxLines,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: courseCode,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (classType.isNotEmpty) ...[
            const TextSpan(text: '\n'),
            TextSpan(
              text: classType,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 10,
                color: resolvedTextColor.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAppointmentsBottomSheet(List<Appointment> appointments) {
    final first = appointments.first;
    final isClassDetails = first.notes == 'class';
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
      if (meta is! _AppointmentMeta) {
        output.add(appointment);
        continue;
      }

      if (meta.type == 'event-overflow') {
        for (final event in meta.events) {
          output.add(
            Appointment(
              startTime: event.startDateTime,
              endTime: event.endDateTime,
              subject: event.title,
              color: AppPrimarySwatch.shade700,
              isAllDay: event.allDay || !_isSameDate(event.startDateTime, event.endDateTime),
              notes: 'event',
              id: _AppointmentMeta(type: 'event', events: [event]),
            ),
          );
        }
        continue;
      }

      if (meta.type == 'event' && meta.events.isNotEmpty) {
        final event = meta.events.first;
        output.add(
          Appointment(
            startTime: event.startDateTime,
            endTime: event.endDateTime,
            subject: event.title,
            color: appointment.color,
            isAllDay: event.allDay || !_isSameDate(event.startDateTime, event.endDateTime),
            notes: 'event',
            id: _AppointmentMeta(type: 'event', events: [event]),
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
    if (meta is _AppointmentMeta &&
        meta.type == 'event' &&
        meta.events.isNotEmpty) {
      final event = meta.events.first;
      final start = event.startDateTime;
      final end = event.endDateTime;
      final sameDay = _isSameDate(start, end);
      if (event.allDay) {
        if (sameDay) {
          return '${start.day} ${monthShortLabel(start.month)} ${start.year} (All day)';
        }
        return '${start.day} ${monthShortLabel(start.month)} ${start.year} - ${end.day} ${monthShortLabel(end.month)} ${end.year} (All day)';
      }
      if (sameDay) {
        return '${start.day} ${monthShortLabel(start.month)} ${start.year} ${_formatTime(start)} - ${_formatTime(end)}';
      }
      return '${start.day} ${monthShortLabel(start.month)} ${start.year} ${_formatTime(start)} - ${end.day} ${monthShortLabel(end.month)} ${end.year} ${_formatTime(end)}';
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
      return '${start.day} ${monthShortLabel(start.month)} ${_formatTime(start)} - ${_formatTime(end)}';
    }
    return '${start.day} ${monthShortLabel(start.month)} ${_formatTime(start)} - ${end.day} ${monthShortLabel(end.month)} ${_formatTime(end)}';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ScheduleModeToggle extends StatelessWidget {
  const _ScheduleModeToggle({
    required this.showMonthly,
    required this.onChanged,
  });

  final bool showMonthly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedSegmentedSwitch<bool>(
      value: showMonthly,
      onChanged: onChanged,
      options: const [
        SegmentedSwitchOption<bool>(value: false, label: 'Weekly'),
        SegmentedSwitchOption<bool>(value: true, label: 'Monthly'),
      ],
    );
  }
}

class _RenderedClassSlot {
  const _RenderedClassSlot({
    required this.courseCode,
    required this.dayIndex,
    required this.startMinutes,
    required this.endMinutes,
    required this.color,
    required this.classType,
  });

  final String courseCode;
  final int dayIndex;
  final int startMinutes;
  final int endMinutes;
  final Color color;
  final ClassType classType;
}

class _ScheduleDataSource extends CalendarDataSource {
  _ScheduleDataSource(List<Appointment> source) {
    appointments = source;
  }
}

class _AppointmentMeta {
  const _AppointmentMeta({
    required this.type,
    this.events = const [],
  });

  final String type;
  final List<AcademicEvent> events;
}

