import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../constants/app_colors.dart';
import '../constants/weekdays.dart';
import '../models/academic_event.dart';
import '../models/class_slot_override.dart';
import '../models/class_type.dart';
import '../models/course.dart';
import '../models/timetable_entry.dart';
import '../utils/course_display.dart';
import '../utils/date_time_format.dart';
import '../utils/event_time_utils.dart';
import '../utils/term_windows.dart';

/// Converts timetable entries + academic events into calendar appointments.
///
/// Keeping this mapping outside the screen makes schedule UI easier to maintain
/// and safer to test without widget dependencies.
class ScheduleAppointmentBuilder {
  static Color parseHexColor(String colorHex) {
    final parsed = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
    return Color(parsed ?? 0xFF6C4DD9);
  }

  static List<Appointment> build({
    required List<TimetableEntry> entries,
    required List<Course> courses,
    required List<AcademicEvent> events,
    List<ClassSlotOverride> classOverrides = const [],
    required TermWindow term,
    required bool forMonthlyAgenda,
    required ScheduleContentFilter contentFilter,
  }) {
    final appointments = <Appointment>[];
    final classSlots = _flattenSlots(entries, courses);
    final includeClasses =
        forMonthlyAgenda || contentFilter != ScheduleContentFilter.eventOnly;
    final includeEvents =
        forMonthlyAgenda || contentFilter != ScheduleContentFilter.timetableOnly;

    // Expand recurring class slots into concrete dates in the selected term.
    if (includeClasses) {
      final overrideById = <String, ClassSlotOverride>{
        for (final item in classOverrides) item.id: item,
      };
      final overrideByOccurrence = <String, ClassSlotOverride>{
        for (final item in classOverrides) item.occurrenceKey: item,
      };
      for (final slot in classSlots) {
        for (var date = DateTime(term.start.year, term.start.month, term.start.day);
            !date.isAfter(term.end);
            date = date.add(const Duration(days: 1))) {
          if ((date.weekday - 1) != slot.dayIndex) continue;
          final sourceDay = weekdayNamesMondayFirst[slot.dayIndex];
          final occurrenceKey = ClassSlotOverride.buildClassSlotOccurrenceKey(
            classSlotId: slot.classSlotId,
            occurrenceDate: date,
          );
          final overrideId = ClassSlotOverride.buildClassSlotOverrideId(
            classSlotId: slot.classSlotId,
            occurrenceDate: date,
          );
          final override =
              overrideById[overrideId] ??
              overrideByOccurrence[occurrenceKey];
          if (override?.action == ClassSlotOverrideAction.cancel) {
            continue;
          }
          final hasOverride = override != null;
          final overrideDate = override?.overrideDate;
          final renderDate = overrideDate == null
              ? date
              : DateTime(overrideDate.year, overrideDate.month, overrideDate.day);
          if (renderDate.isBefore(DateTime(term.start.year, term.start.month, term.start.day)) ||
              renderDate.isAfter(DateTime(term.end.year, term.end.month, term.end.day))) {
            continue;
          }
          final effectiveStartMinutes =
              override?.overrideStartMinutes ?? slot.startMinutes;
          final effectiveEndMinutes = override?.overrideEndMinutes ?? slot.endMinutes;
          final effectiveMode = override?.overrideMode ?? slot.mode;
          final effectiveVenue = override?.overrideVenue ?? slot.venue;
          final start = DateTime(
            renderDate.year,
            renderDate.month,
            renderDate.day,
            effectiveStartMinutes ~/ 60,
            effectiveStartMinutes % 60,
          );
          final end = DateTime(
            renderDate.year,
            renderDate.month,
            renderDate.day,
            effectiveEndMinutes ~/ 60,
            effectiveEndMinutes % 60,
          );
          if (!end.isAfter(start)) continue;

          final hideClassEventsForSlot = events
              .where(
                (e) =>
                    e.hideClassesDuringEvent &&
                    !e.isAcademicBreak &&
                    e.sessionId == slot.sessionId &&
                    e.termId == slot.termId,
              )
              .toList(growable: false);
          if (hideClassEventsForSlot.isNotEmpty &&
              isFullyCoveredByAnyEvent(
                innerStart: start,
                innerEnd: end,
                events: hideClassEventsForSlot,
              )) {
            continue;
          }
          final academicBreakEventsForSlot = events
              .where(
                (e) =>
                    e.isAcademicBreak &&
                    e.sessionId == slot.sessionId &&
                    e.termId == slot.termId,
              )
              .toList(growable: false);
          if (!hasOverride &&
              academicBreakEventsForSlot.isNotEmpty &&
              isFullyCoveredByAnyEvent(
                innerStart: start,
                innerEnd: end,
                events: academicBreakEventsForSlot,
              )) {
            continue;
          }

          final modeLower = effectiveMode.toLowerCase();
          final venueLabel = modeLower == 'online'
              ? 'Online'
              : (effectiveVenue != null && effectiveVenue.trim().isNotEmpty
                  ? effectiveVenue.trim()
                  : '');
          appointments.add(
            Appointment(
              startTime: start,
              endTime: end,
              subject: venueLabel.isNotEmpty
                  ? '${slot.courseCode}\n$venueLabel'
                  : slot.courseCode,
              color: slot.color,
              isAllDay: false,
              notes: ScheduleAppointmentMeta.typeClass,
              id: ScheduleAppointmentMeta(
                type: ScheduleAppointmentMeta.typeClass,
                mode: effectiveMode,
                venue: effectiveVenue,
                classSessionId: slot.sessionId,
                classTermId: slot.termId,
                classCourseCode: slot.courseCode,
                classSlotId: slot.classSlotId,
                classOccurrenceDate: date,
                classSourceDay: sourceDay,
                classSourceStartMinutes: slot.startMinutes,
                classSourceEndMinutes: slot.endMinutes,
                classType: slot.classType.label,
              ),
            ),
          );
        }
      }
    }

    // Weekly "Timetable only" mode stops after class mapping.
    if (!includeEvents) return appointments;

    final allDayEvents = events
        .where((e) => e.allDay || !isSameDate(e.startDateTime, e.endDateTime))
        .toList(growable: false);
    final timedEvents = events
        .where((e) => !e.allDay && isSameDate(e.startDateTime, e.endDateTime))
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
            color: appPrimarySwatch.shade700,
            isAllDay: event.allDay,
            notes: ScheduleAppointmentMeta.typeEvent,
            id: ScheduleAppointmentMeta(
              type: ScheduleAppointmentMeta.typeEvent,
              events: [event],
            ),
          ),
        );
      }
      return appointments;
    }

    // Cap all-day lane to two rows per day: [A, B] or [A, +X].
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
        _buildEventAppointment(
          event: firstEvent,
          startTime: dayStart,
          endTime: dayEnd,
          isAllDay: true,
        ),
      );
      if (dayEvents.length == 2) {
        final secondEvent = dayEvents[1];
        appointments.add(
          _buildEventAppointment(
            event: secondEvent,
            startTime: dayStart,
            endTime: dayEnd,
            isAllDay: true,
          ),
        );
      } else if (dayEvents.length > 2) {
        final hiddenEvents = dayEvents.skip(1).toList(growable: false);
        appointments.add(
          _buildEventOverflowAppointment(
            startTime: dayStart,
            endTime: dayEnd,
            isAllDay: true,
            hiddenEvents: hiddenEvents,
          ),
        );
      }
    }

    final groupedTimedEvents = <String, List<AcademicEvent>>{};
    for (final event in timedEvents) {
      final key =
          '${event.startDateTime.millisecondsSinceEpoch}|${event.endDateTime.millisecondsSinceEpoch}';
      groupedTimedEvents.putIfAbsent(key, () => <AcademicEvent>[]).add(event);
    }
    for (final group in groupedTimedEvents.values) {
      group.sort((a, b) => a.title.compareTo(b.title));
      // In weekly/day rendering, keep timed events as individual appointments.
      // This allows dense-overlap compression to compute a single +N that
      // correctly counts classes + tasks + events together.
      if (!forMonthlyAgenda) {
        for (final event in group) {
          appointments.add(
            _buildEventAppointment(
              event: event,
              startTime: event.startDateTime,
              endTime: event.endDateTime,
              isAllDay: false,
            ),
          );
        }
        continue;
      }
      if (group.length <= 2) {
        for (final event in group) {
          appointments.add(
            _buildEventAppointment(
              event: event,
              startTime: event.startDateTime,
              endTime: event.endDateTime,
              isAllDay: false,
            ),
          );
        }
        continue;
      }

      final leadEvent = group.first;
      appointments.add(
        _buildEventAppointment(
          event: leadEvent,
          startTime: leadEvent.startDateTime,
          endTime: leadEvent.endDateTime,
          isAllDay: false,
        ),
      );
      appointments.add(
        _buildEventOverflowAppointment(
          startTime: leadEvent.startDateTime,
          endTime: leadEvent.endDateTime,
          isAllDay: false,
          hiddenEvents: group.skip(1).toList(growable: false),
        ),
      );
    }

    // Keep weekly/day output raw here; caller can merge extra sources
    // (e.g. tasks) and run a single dense-overlap compression pass.
    return appointments;
  }

  /// Public helper for screens that merge additional timed items (e.g. tasks)
  /// after [build] and still need dense-overlap compression.
  static List<Appointment> compressDenseOverlapsForDisplay(
    List<Appointment> appointments,
  ) {
    return _compressDenseOverlaps(appointments);
  }

  /// Keep <=2 overlapping timed items as-is. For >2 overlapping items in a day,
  /// render one longest item plus a "+N" overflow block.
  static List<Appointment> _compressDenseOverlaps(List<Appointment> input) {
    final allDay = <Appointment>[];
    final timedByDay = <String, List<Appointment>>{};

    for (final appt in input) {
      if (appt.isAllDay) {
        allDay.add(appt);
        continue;
      }
      final dayKey =
          '${appt.startTime.year}-${appt.startTime.month}-${appt.startTime.day}';
      timedByDay.putIfAbsent(dayKey, () => <Appointment>[]).add(appt);
    }

    final compressedTimed = <Appointment>[];
    for (final day in timedByDay.values) {
      day.sort(_compareAppointmentsByStartThenEnd);

      var cluster = <Appointment>[];
      DateTime? clusterEnd;

      void flushCluster() {
        if (cluster.isEmpty) return;
        if (cluster.length <= 2) {
          compressedTimed.addAll(cluster);
          cluster = <Appointment>[];
          clusterEnd = null;
          return;
        }

        Appointment lead = cluster.first;
        var leadDuration = lead.endTime.difference(lead.startTime);
        for (final candidate in cluster.skip(1)) {
          final candidateDuration =
              candidate.endTime.difference(candidate.startTime);
          final isLonger = candidateDuration > leadDuration;
          final isSameLengthEarlier =
              candidateDuration == leadDuration &&
                  candidate.startTime.isBefore(lead.startTime);
          if (isLonger || isSameLengthEarlier) {
            lead = candidate;
            leadDuration = candidateDuration;
          }
        }

        final others =
            cluster.where((a) => !identical(a, lead)).toList(growable: false);
        var earliestStart = others.first.startTime;
        var latestEnd = others.first.endTime;
        for (final appt in others.skip(1)) {
          if (appt.startTime.isBefore(earliestStart)) {
            earliestStart = appt.startTime;
          }
          if (appt.endTime.isAfter(latestEnd)) {
            latestEnd = appt.endTime;
          }
        }
        if (!latestEnd.isAfter(earliestStart)) {
          latestEnd = earliestStart.add(const Duration(minutes: 1));
        }

        final overflowAppointment = Appointment(
          startTime: earliestStart,
          endTime: latestEnd,
          subject: '+${others.length}',
          color: appPrimarySwatch.shade800,
          isAllDay: false,
          notes: ScheduleAppointmentMeta.typeDenseOverflow,
          id: ScheduleAppointmentMeta(
            type: ScheduleAppointmentMeta.typeDenseOverflow,
            overflowAppointments: others,
          ),
        );

        // Put overflow first so lead block is laid out as the primary item.
        compressedTimed.add(overflowAppointment);
        compressedTimed.add(lead);

        cluster = <Appointment>[];
        clusterEnd = null;
      }

      for (final appt in day) {
        if (cluster.isEmpty) {
          cluster = [appt];
          clusterEnd = appt.endTime;
          continue;
        }

        final overlapsCluster = appt.startTime.isBefore(clusterEnd!);
        if (overlapsCluster) {
          cluster.add(appt);
          if (appt.endTime.isAfter(clusterEnd!)) {
            clusterEnd = appt.endTime;
          }
        } else {
          flushCluster();
          cluster = [appt];
          clusterEnd = appt.endTime;
        }
      }
      flushCluster();
    }

    final output = <Appointment>[
      ...allDay,
      ...compressedTimed,
    ];
    output.sort(_compareAppointmentsForRenderOrder);
    return output;
  }

  static int _compareAppointmentsByStartThenEnd(Appointment a, Appointment b) {
    final byStart = a.startTime.compareTo(b.startTime);
    if (byStart != 0) return byStart;
    return a.endTime.compareTo(b.endTime);
  }

  static int _compareAppointmentsForRenderOrder(Appointment a, Appointment b) {
    final byStart = a.startTime.compareTo(b.startTime);
    if (byStart != 0) return byStart;
    final aIsOverflowSubject = a.subject.trim().startsWith('+');
    final bIsOverflowSubject = b.subject.trim().startsWith('+');
    if (aIsOverflowSubject != bIsOverflowSubject) {
      return aIsOverflowSubject ? 1 : -1;
    }
    return a.endTime.compareTo(b.endTime);
  }

  /// Single-event [Appointment] for calendar/detail sheets (not expanded for overflow).
  static Appointment appointmentForEventDetail(AcademicEvent event) {
    return _buildEventAppointment(
      event: event,
      startTime: event.startDateTime,
      endTime: event.endDateTime,
      isAllDay: event.allDay,
    );
  }

  static Appointment _buildEventAppointment({
    required AcademicEvent event,
    required DateTime startTime,
    required DateTime endTime,
    required bool isAllDay,
  }) {
    return Appointment(
      startTime: startTime,
      endTime: endTime,
      subject: event.title,
      color: appPrimarySwatch.shade700,
      isAllDay: isAllDay,
      notes: ScheduleAppointmentMeta.typeEvent,
      id: ScheduleAppointmentMeta(
        type: ScheduleAppointmentMeta.typeEvent,
        events: [event],
      ),
    );
  }

  static Appointment _buildEventOverflowAppointment({
    required DateTime startTime,
    required DateTime endTime,
    required bool isAllDay,
    required List<AcademicEvent> hiddenEvents,
  }) {
    return Appointment(
      startTime: startTime,
      endTime: endTime,
      subject: '+${hiddenEvents.length}',
      color: appPrimarySwatch.shade800,
      isAllDay: isAllDay,
      notes: ScheduleAppointmentMeta.typeEventOverflow,
      id: ScheduleAppointmentMeta(
        type: ScheduleAppointmentMeta.typeEventOverflow,
        events: hiddenEvents,
      ),
    );
  }

  static List<_RenderedClassSlot> _flattenSlots(
    List<TimetableEntry> entries,
    List<Course> courses,
  ) {
    final output = <_RenderedClassSlot>[];
    for (final entry in entries) {
      final displayCode =
          displayCourseCodeForTimetableEntry(entry, courses);
      final color = displayCourseColorForTimetableEntry(entry, courses);
      for (final slot in entry.slots) {
        final dayIndex = weekdayIndexFromString(slot.day);
        if (dayIndex == -1) continue;
        final start = _parseMinutes(slot.startTime);
        final end = _parseMinutes(slot.endTime);
        if (start == null || end == null || end <= start) continue;
        output.add(
          _RenderedClassSlot(
            sessionId: entry.sessionId,
            termId: entry.termId,
            courseCode: displayCode,
            classSlotId: slot.classSlotId,
            dayIndex: dayIndex,
            startMinutes: start,
            endMinutes: end,
            color: color,
            classType: slot.classType,
            mode: slot.mode,
            venue: slot.venue,
          ),
        );
      }
    }
    return output;
  }

  static int? _parseMinutes(String value) {
    return parseTimeLabel12hToMinutes(value);
  }

}

class ScheduleAppointmentMeta {
  const ScheduleAppointmentMeta({
    required this.type,
    this.events = const [],
    this.mode,
    this.venue,
    this.overflowAppointments = const [],
    this.classSessionId,
    this.classTermId,
    this.classCourseCode,
    this.classSlotId,
    this.classOccurrenceDate,
    this.classSourceDay,
    this.classSourceStartMinutes,
    this.classSourceEndMinutes,
    this.classType,
    this.taskId,
    this.taskDueDateTime,
  });

  static const String typeClass = 'class';
  static const String typeEvent = 'event';
  static const String typeEventOverflow = 'event-overflow';
  static const String typeDenseOverflow = 'dense-overflow';
  static const String typeTask = 'task';

  final String type;
  final List<AcademicEvent> events;
  final String? mode;
  final String? venue;
  final List<Appointment> overflowAppointments;
  final String? classSessionId;
  final String? classTermId;
  final String? classCourseCode;
  final String? classSlotId;
  final DateTime? classOccurrenceDate;
  final String? classSourceDay;
  final int? classSourceStartMinutes;
  final int? classSourceEndMinutes;
  final String? classType;
  final String? taskId;
  final DateTime? taskDueDateTime;
}

enum ScheduleContentFilter {
  timetableOnly,
  eventOnly,
  both,
}

class _RenderedClassSlot {
  const _RenderedClassSlot({
    required this.sessionId,
    required this.termId,
    required this.courseCode,
    required this.classSlotId,
    required this.dayIndex,
    required this.startMinutes,
    required this.endMinutes,
    required this.color,
    required this.classType,
    required this.mode,
    this.venue,
  });

  final String sessionId;
  final String termId;
  final String courseCode;
  final String classSlotId;
  final int dayIndex;
  final int startMinutes;
  final int endMinutes;
  final Color color;
  final ClassType classType;
  final String mode;
  final String? venue;
}
