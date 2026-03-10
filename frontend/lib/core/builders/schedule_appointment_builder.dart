import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../constants/app_colors.dart';
import '../constants/weekdays.dart';
import '../models/academic_event.dart';
import '../models/class_type.dart';
import '../models/timetable_entry.dart';
import '../utils/date_time_format.dart';
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
    required Map<String, Color> courseColorByCode,
    required List<AcademicEvent> events,
    required TermWindow term,
    required bool forMonthlyAgenda,
    required ScheduleContentFilter contentFilter,
  }) {
    final appointments = <Appointment>[];
    final classSlots = _flattenSlots(entries, courseColorByCode);
    final includeClasses =
        forMonthlyAgenda || contentFilter != ScheduleContentFilter.eventOnly;
    final includeEvents =
        forMonthlyAgenda || contentFilter != ScheduleContentFilter.timetableOnly;

    // Expand recurring class slots into concrete dates in the selected term.
    if (includeClasses) {
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
              notes: ScheduleAppointmentMeta.typeClass,
              id: const ScheduleAppointmentMeta(type: ScheduleAppointmentMeta.typeClass),
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
            color: AppPrimarySwatch.shade700,
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
        Appointment(
          startTime: dayStart,
          endTime: dayEnd,
          subject: firstEvent.title,
          color: AppPrimarySwatch.shade700,
          isAllDay: true,
          notes: ScheduleAppointmentMeta.typeEvent,
          id: ScheduleAppointmentMeta(
            type: ScheduleAppointmentMeta.typeEvent,
            events: [firstEvent],
          ),
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
            notes: ScheduleAppointmentMeta.typeEvent,
            id: ScheduleAppointmentMeta(
              type: ScheduleAppointmentMeta.typeEvent,
              events: [secondEvent],
            ),
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
            notes: ScheduleAppointmentMeta.typeEventOverflow,
            id: ScheduleAppointmentMeta(
              type: ScheduleAppointmentMeta.typeEventOverflow,
              events: hiddenEvents,
            ),
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
      if (group.length <= 2) {
        for (final event in group) {
          appointments.add(
            Appointment(
              startTime: event.startDateTime,
              endTime: event.endDateTime,
              subject: event.title,
              color: AppPrimarySwatch.shade700,
              isAllDay: false,
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

      final leadEvent = group.first;
      appointments.add(
        Appointment(
          startTime: leadEvent.startDateTime,
          endTime: leadEvent.endDateTime,
          subject: leadEvent.title,
          color: AppPrimarySwatch.shade700,
          isAllDay: false,
          notes: ScheduleAppointmentMeta.typeEvent,
          id: ScheduleAppointmentMeta(
            type: ScheduleAppointmentMeta.typeEvent,
            events: [leadEvent],
          ),
        ),
      );
      appointments.add(
        Appointment(
          startTime: leadEvent.startDateTime,
          endTime: leadEvent.endDateTime,
          subject: '+${group.length - 1}',
          color: AppPrimarySwatch.shade800,
          isAllDay: false,
          notes: ScheduleAppointmentMeta.typeEventOverflow,
          id: ScheduleAppointmentMeta(
            type: ScheduleAppointmentMeta.typeEventOverflow,
            events: group.skip(1).toList(growable: false),
          ),
        ),
      );
    }

    return appointments;
  }

  static List<_RenderedClassSlot> _flattenSlots(
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

  static int? _parseMinutes(String value) {
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
}

class ScheduleAppointmentMeta {
  const ScheduleAppointmentMeta({
    required this.type,
    this.events = const [],
  });

  static const String typeClass = 'class';
  static const String typeEvent = 'event';
  static const String typeEventOverflow = 'event-overflow';

  final String type;
  final List<AcademicEvent> events;
}

enum ScheduleContentFilter {
  timetableOnly,
  eventOnly,
  both,
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
