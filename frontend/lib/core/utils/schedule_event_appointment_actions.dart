import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../builders/schedule_appointment_builder.dart';
import '../services/academic_event_store.dart';
import '../widgets/common/confirm_dialog.dart';
import '../../screens/schedule/schedule_event_editor_screen.dart';
import 'term_windows.dart';

/// Core edit flow after the details bottom sheet is already closed (e.g. schedule screen).
Future<void> runScheduleEventAppointmentEdit(
  BuildContext context,
  Appointment appointment, {
  required TermWindow selectedTerm,
}) async {
  final meta = appointment.id;
  if (meta is! ScheduleAppointmentMeta) return;
  if (meta.type != ScheduleAppointmentMeta.typeEvent || meta.events.isEmpty) {
    return;
  }
  final updated = await ScheduleEventEditorScreen.show(
    context,
    initialEvent: meta.events.first,
    selectedTerm: selectedTerm,
  );
  if (updated == null || !context.mounted) return;
  await updateAcademicEvent(updated);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Event updated.')),
  );
}

/// Pops the sheet then runs [runScheduleEventAppointmentEdit] (home / sheet callbacks).
Future<void> scheduleEventAppointmentEdit(
  BuildContext context,
  Appointment appointment, {
  required TermWindow selectedTerm,
}) async {
  Navigator.of(context).pop();
  await runScheduleEventAppointmentEdit(
    context,
    appointment,
    selectedTerm: selectedTerm,
  );
}

/// Core delete flow after the details bottom sheet is already closed.
Future<void> runScheduleEventAppointmentDelete(
  BuildContext context,
  Appointment appointment,
) async {
  final meta = appointment.id;
  if (meta is! ScheduleAppointmentMeta) return;
  if (meta.type != ScheduleAppointmentMeta.typeEvent || meta.events.isEmpty) {
    return;
  }
  final event = meta.events.first;
  final shouldDelete = await showConfirmDeleteDialog(
    context,
    title: 'Delete Event',
    message: 'Are you sure you want to delete this event?',
  );
  if (!shouldDelete) return;
  await deleteAcademicEvent(event.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Event deleted.')),
  );
}

/// Pops the sheet then runs [runScheduleEventAppointmentDelete].
Future<void> scheduleEventAppointmentDelete(
  BuildContext context,
  Appointment appointment,
) async {
  Navigator.of(context).pop();
  await runScheduleEventAppointmentDelete(context, appointment);
}
