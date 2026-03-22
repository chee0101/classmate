import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../builders/schedule_appointment_builder.dart';
import '../../constants/app_spacing.dart';
import '../../utils/schedule_appointment_details.dart';
import 'schedule_details_sheet.dart';

/// Same bottom sheet used on the schedule screen: single [ScheduleDetailsSheet] or
/// a scrollable list of appointments (e.g. multiple events).
Future<void> showScheduleAppointmentsBottomSheet({
  required BuildContext context,
  required List<Appointment> appointments,
  required Future<void> Function(Appointment appointment) onEditAppointment,
  required Future<void> Function(Appointment appointment) onCancelAppointment,
}) async {
  if (appointments.isEmpty) return;

  final first = appointments.first;
  final isClassDetails = first.notes == ScheduleAppointmentMeta.typeClass;
  final sheetTitle = appointments.length == 1
      ? (isClassDetails ? 'Class Details' : 'Event Details')
      : 'Details';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.75;
      final isSingle = appointments.length == 1;
      if (isSingle) {
        final appointment = appointments.first;
        if (isClassDetails) {
          return ScheduleDetailsSheet(
            sheetTitle: sheetTitle,
            appointment: appointment,
            type: ScheduleDetailsType.classDetails,
            onEditPressed: () => onEditAppointment(appointment),
            onCancelPressed: () => onCancelAppointment(appointment),
          );
        } else {
          return ScheduleDetailsSheet(
            sheetTitle: sheetTitle,
            appointment: appointment,
            type: ScheduleDetailsType.eventDetails,
            onEditPressed: () => onEditAppointment(appointment),
            onCancelPressed: () => onCancelAppointment(appointment),
          );
        }
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
                                    formatAppointmentRange(appointment),
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
