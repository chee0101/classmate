import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../builders/schedule_appointment_builder.dart';
import '../constants/app_colors.dart';
import 'date_time_format.dart';

bool isOverflowAppointment(Appointment appointment) {
  final meta = appointment.id;
  if (meta is! ScheduleAppointmentMeta) return false;
  return meta.type == ScheduleAppointmentMeta.typeEventOverflow ||
      meta.type == ScheduleAppointmentMeta.typeDenseOverflow;
}

List<Appointment> expandAppointmentsForDetails(List<Appointment> appointments) {
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
            isAllDay:
                event.allDay || !isSameDate(event.startDateTime, event.endDateTime),
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

    if (meta.type == ScheduleAppointmentMeta.typeDenseOverflow &&
        meta.overflowAppointments.isNotEmpty) {
      for (final hidden in meta.overflowAppointments) {
        final hiddenMeta = hidden.id;
        if (hiddenMeta is ScheduleAppointmentMeta &&
            hiddenMeta.type == ScheduleAppointmentMeta.typeEventOverflow) {
          for (final event in hiddenMeta.events) {
            output.add(
              Appointment(
                startTime: event.startDateTime,
                endTime: event.endDateTime,
                subject: event.title,
                color: AppPrimarySwatch.shade700,
                isAllDay: event.allDay ||
                    !isSameDate(event.startDateTime, event.endDateTime),
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
        output.add(hidden);
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

String formatMonthlyAgendaSubtitle(Appointment appointment) {
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
      return formatTimeRange12h(event.startDateTime, event.endDateTime);
    }
    return formatDateTimeRange(event.startDateTime, event.endDateTime);
  }
  if (!appointment.isAllDay && isSameDate(appointment.startTime, appointment.endTime)) {
    return formatTimeRange12h(appointment.startTime, appointment.endTime);
  }
  return formatAppointmentRange(appointment);
}

String formatAppointmentRange(Appointment appointment) {
  final meta = appointment.id;
  if (appointment.notes == ScheduleAppointmentMeta.typeClass) {
    final start = appointment.startTime;
    final end = appointment.endTime;
    return formatWeekdayTimeRange(start, end);
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

  final start = appointment.startTime;
  final end = appointment.endTime;
  if (appointment.isAllDay) {
    return formatAllDayRange(start, end);
  }
  return formatDateTimeRange(start, end);
}

String formatOverflowPopupSubtitle(Appointment appointment) {
  if (appointment.notes == ScheduleAppointmentMeta.typeClass) {
    final start = appointment.startTime;
    final end = appointment.endTime;
    return formatWeekdayTimeRange(start, end, dayTimeSeparator: ' • ');
  }
  return formatAppointmentRange(appointment);
}
