import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../core/builders/schedule_appointment_builder.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/academic_event.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/course.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/services/academic_event_store.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/utils/schedule_appointment_details.dart';
import '../../core/utils/session_term_resolver.dart';
import '../../core/models/session_term_ref.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/common/session_term_context_label.dart';
import '../../core/widgets/schedule/schedule_class_appointment_text.dart';
import '../../core/widgets/schedule/schedule_overflow_popup_menu.dart';
import '../../core/widgets/schedule/schedule_mode_toggle.dart';
import '../../core/widgets/schedule/schedule_details_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _showMonthly = false;
  final CalendarController _calendarController = CalendarController();
  DateTime _visibleDate = DateTime.now();
  Offset? _lastPointerGlobalPosition;

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
                                          final middle = details
                                              .visibleDates[details.visibleDates.length ~/ 2];
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
                                            return Listener(
                                              behavior: HitTestBehavior.translucent,
                                              onPointerDown: (event) {
                                                _lastPointerGlobalPosition =
                                                    event.position;
                                              },
                                              child: Container(
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
                                                    formatMonthlyAgendaSubtitle(
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
                                            ),
                                            );
                                          }
                                          final maxAppointmentLines =
                                              appointment.isAllDay ? 1 : 3;
                                          return Listener(
                                            behavior: HitTestBehavior.translucent,
                                            onPointerDown: (event) {
                                              _lastPointerGlobalPosition =
                                                  event.position;
                                            },
                                            child: Container(
                                            padding: const EdgeInsets.all(3),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: appointment.color
                                                  .withValues(alpha: 0.26),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child:
                                                appointment.notes ==
                                                        ScheduleAppointmentMeta.typeClass
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
                                          ),
                                          );
                                        },
                                        onTap: (details) async {
                                          // In monthly view, don't open details when tapping
                                          // the grid/date cells. Only event blocks are tappable.
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

                                          if (appointments.length == 1 &&
                                              isOverflowAppointment(
                                                appointments.first,
                                              )) {
                                            await _showOverflowPicker(
                                              appointments.first,
                                            );
                                            return;
                                          }

                                          final detailAppointments =
                                              expandAppointmentsForDetails(appointments);
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
        final isSingle = appointments.length == 1;
        if (isSingle) {
          final appointment = appointments.first;
          if (isClassDetails) {
            return ScheduleDetailsSheet(
              sheetTitle: sheetTitle,
              appointment: appointment,
              type: ScheduleDetailsType.classDetails,
            );
          } else {
            return ScheduleDetailsSheet(
              sheetTitle: sheetTitle,
              appointment: appointment,
              type: ScheduleDetailsType.eventDetails,
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

  Future<void> _showOverflowPicker(Appointment overflowAppointment) async {
    final hiddenItems = expandAppointmentsForDetails([overflowAppointment]);
    if (hiddenItems.isEmpty || !mounted) return;

    final selected = await showScheduleOverflowPopupMenu(
      context: context,
      tapPosition: _lastPointerGlobalPosition,
      hiddenItems: hiddenItems,
      formatAppointmentRange: formatOverflowPopupSubtitle,
    );

    if (selected == null || !mounted) return;
    _showAppointmentsBottomSheet([selected]);
  }
}

class _ScheduleDataSource extends CalendarDataSource {
  _ScheduleDataSource(List<Appointment> source) {
    appointments = source;
  }
}
