import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../core/builders/schedule_appointment_builder.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/academic_event.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/class_slot_override.dart';
import '../../core/models/class_type.dart';
import '../../core/models/course.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/services/academic_event_store.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/class_slot_override_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/utils/schedule_appointment_details.dart';
import '../../core/utils/session_term_resolver.dart';
import '../../core/utils/term_windows.dart';
import '../../core/models/session_term_ref.dart';
import '../../core/utils/day_bounds_utils.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/common/session_term_context_label.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/schedule/class_slot_sheet.dart';
import '../../core/widgets/schedule/schedule_class_appointment_text.dart';
import '../../core/widgets/schedule/schedule_overflow_popup_menu.dart';
import '../../core/widgets/schedule/schedule_details_sheet.dart';
import 'schedule_class_editor_screen.dart';
import 'schedule_event_editor_screen.dart';
import '../../core/utils/event_time_utils.dart';
import '../../core/utils/schedule_week_utils.dart';

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
                padding: const EdgeInsets.all(AppSpacing.md),
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
                      return ValueListenableBuilder<List<ClassSlotOverride>>(
                        valueListenable: classSlotOverridesNotifier,
                        builder: (context, classOverrides, _) {
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
                                for (final c in coursesForSessionAndTerm(
                                  sessionId: selectedSession.id,
                                  termId: selectedTerm.id,
                                ))
                                  c.courseCode:
                                      ScheduleAppointmentBuilder.parseHexColor(
                                    c.courseColor,
                                  ),
                              };

                              final selectedTermEvents = events
                                  .where(
                                    (event) =>
                                        event.sessionId == selectedSession.id &&
                                        event.termId == selectedTerm.id,
                                  )
                                  .toList(growable: false);
                              final visibleDay = DateTime(
                                _visibleDate.year,
                                _visibleDate.month,
                                _visibleDate.day,
                              );
                          final visibleStartOfDay = startOfDay(visibleDay);
                          final visibleEndOfDay = endOfDayInclusive(visibleDay);
                              final eventsOnVisibleDay = selectedTermEvents
                                  .where(
                                    (event) =>
                                        !event.endDateTime
                                            .isBefore(visibleStartOfDay) &&
                                        !event.startDateTime
                                            .isAfter(visibleEndOfDay),
                                  )
                                  .toList(growable: false);

                              AcademicEvent? academicBreakEvent;
                              final hideClassEvents = <AcademicEvent>[];
                              for (final event in eventsOnVisibleDay) {
                                if (event.isAcademicBreak) {
                                  academicBreakEvent = event;
                                } else if (event.hideClassesDuringEvent) {
                                  hideClassEvents.add(event);
                                }
                              }
                              final isAcademicBreakOnVisibleDay =
                                  academicBreakEvent != null;
                              final hasHideClassEventsOnVisibleDay =
                                  !isAcademicBreakOnVisibleDay &&
                                      hideClassEvents.isNotEmpty;
                              final selectedClassSlotIds = filteredEntries
                                  .expand((entry) => entry.slots
                                      .map((slot) => slot.classSlotId))
                                  .toSet();
                              final selectedClassOverrides = classOverrides
                                  .where(
                                    (item) => selectedClassSlotIds
                                        .contains(item.classSlotId),
                                  )
                                  .toList(growable: false);
                              final appointments =
                                  ScheduleAppointmentBuilder.build(
                                entries: filteredEntries,
                                courseColorByCode: courseColorByCode,
                                events: selectedTermEvents,
                                classOverrides: selectedClassOverrides,
                                term: selectedTerm,
                                forMonthlyAgenda: _showMonthly,
                                contentFilter: ScheduleContentFilter.both,
                              );

                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.md,
                                        0,
                                        AppSpacing.md,
                                        AppSpacing.sm),
                                    child: SessionTermContextLabel(
                                      sessionName: selectedSession.name,
                                      termLabel: selectedTerm.label,
                                    ),
                                  ),
                                  if (buildWeekBannerText(
                                              selectedTerm, _visibleDate) !=
                                          '' &&
                                      !_showMonthly)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.md,
                                        0,
                                        AppSpacing.md,
                                        AppSpacing.sm,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2E4FD),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    buildWeekBannerText(
                                                      selectedTerm,
                                                      _visibleDate,
                                                    ),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  if (isAcademicBreakOnVisibleDay)
                                                    Text(
                                                      'No classes',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                ])),
                                      ),
                                    ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.sm,
                                        0,
                                        AppSpacing.sm,
                                        AppSpacing.sm,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: SfCalendar(
                                                controller: _calendarController,
                                                allowedViews: const [
                                                  // CalendarView.day,
                                                  CalendarView.week,
                                                  CalendarView.month,
                                                ],
                                                backgroundColor: Colors.white,
                                                dataSource: _ScheduleDataSource(
                                                    appointments),
                                                firstDayOfWeek: 1,
                                                headerHeight: 40,
                                                headerStyle:
                                                    const CalendarHeaderStyle(
                                                  backgroundColor:
                                                      Color(0xFFCBCDFA),
                                                  textStyle: TextStyle(
                                                      color: Colors.black),
                                                ),
                                                showNavigationArrow: false,
                                                showDatePickerButton: true,
                                                viewHeaderStyle:
                                                    const ViewHeaderStyle(
                                                  backgroundColor:
                                                      Color(0xFFE2E4FD),
                                                ),
                                                showCurrentTimeIndicator: true,
                                                selectionDecoration:
                                                    const BoxDecoration(
                                                  color: Colors.transparent,
                                                ),
                                                onViewChanged: (details) {
                                                  if (details.visibleDates
                                                      .isEmpty) return;
                                                  final middle = details
                                                      .visibleDates[details
                                                          .visibleDates
                                                          .length ~/
                                                      2];
                                                  final currentView =
                                                      _calendarController.view;
                                                  if (!mounted ||
                                                      _visibleDate == middle)
                                                    return;
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback(
                                                          (_) {
                                                    if (!mounted ||
                                                        _visibleDate == middle)
                                                      return;
                                                    setState(() {
                                                      _visibleDate = middle;
                                                      _showMonthly =
                                                          currentView ==
                                                              CalendarView
                                                                  .month;
                                                    });
                                                  });
                                                },
                                                monthViewSettings:
                                                    const MonthViewSettings(
                                                  appointmentDisplayMode:
                                                      MonthAppointmentDisplayMode
                                                          .indicator,
                                                  showAgenda: true,
                                                  agendaItemHeight: 44,
                                                  agendaStyle: AgendaStyle(
                                                    backgroundColor:
                                                        Color(0xFFE2E4FD),
                                                  ),
                                                ),
                                                timeSlotViewSettings:
                                                    const TimeSlotViewSettings(
                                                  startHour: 0,
                                                  endHour: 24,
                                                  timeIntervalHeight: 64,
                                                ),
                                                appointmentBuilder: (context,
                                                    calendarAppointmentDetails) {
                                                  final appointment =
                                                      calendarAppointmentDetails
                                                          .appointments
                                                          .first as Appointment;
                                                  if (_showMonthly) {
                                                    return Listener(
                                                      behavior: HitTestBehavior
                                                          .translucent,
                                                      onPointerDown: (event) {
                                                        _lastPointerGlobalPosition =
                                                            event.position;
                                                      },
                                                      child: Container(
                                                        margin: const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 2,
                                                          vertical: 1,
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 3,
                                                        ),
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: appointment
                                                              .color
                                                              .withValues(
                                                                  alpha: 0.14),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          border: Border.all(
                                                            color: appointment
                                                                .color
                                                                .withValues(
                                                                    alpha:
                                                                        0.45),
                                                            width: 0.7,
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              appointment
                                                                  .subject,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                                height: 1.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              formatMonthlyAgendaSubtitle(
                                                                appointment,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                height: 1.0,
                                                                color: Colors
                                                                    .grey
                                                                    .shade700,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  final maxAppointmentLines =
                                                      appointment.isAllDay
                                                          ? 1
                                                          : 3;
                                                  final isClassAppointment =
                                                      appointment.notes ==
                                                          ScheduleAppointmentMeta
                                                              .typeClass;

                                                  final isDisabledDueToHideEvent =
                                                      !isAcademicBreakOnVisibleDay &&
                                                          hasHideClassEventsOnVisibleDay &&
                                                          isClassAppointment &&
                                                          isFullyCoveredByAnyEvent(
                                                            innerStart:
                                                                appointment
                                                                    .startTime,
                                                            innerEnd:
                                                                appointment.endTime,
                                                            events: hideClassEvents,
                                                          );

                                                  final isDisabled = isAcademicBreakOnVisibleDay ||
                                                      isDisabledDueToHideEvent;

                                                  return Listener(
                                                    behavior: HitTestBehavior
                                                        .translucent,
                                                    onPointerDown: (event) {
                                                      _lastPointerGlobalPosition =
                                                          event.position;
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              3),
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: appointment.color
                                                            .withValues(
                                                                alpha: 0.26),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: isClassAppointment
                                                          ? Opacity(
                                                              opacity:
                                                                  isDisabled
                                                                      ? 0.35
                                                                      : 1.0,
                                                              child:
                                                                  ScheduleClassAppointmentText(
                                                                subject:
                                                                    appointment
                                                                        .subject,
                                                                textColor:
                                                                    appointment
                                                                        .color,
                                                                maxLines:
                                                                    maxAppointmentLines,
                                                              ),
                                                            )
                                                          : Text(
                                                              appointment
                                                                  .subject,
                                                              maxLines:
                                                                  maxAppointmentLines,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: appPrimarySwatch
                                                                        .shade900,
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
                                                          CalendarElement
                                                              .calendarCell) {
                                                    return;
                                                  }
                                                  final rawAppointments =
                                                      details.appointments;
                                                  if (rawAppointments == null ||
                                                      rawAppointments.isEmpty ||
                                                      !mounted) {
                                                    return;
                                                  }

                                                  final appointments =
                                                      rawAppointments
                                                          .whereType<
                                                              Appointment>()
                                                          .toList(
                                                              growable: false);
                                                  if (appointments.isEmpty)
                                                    return;

                                                  // During academic breaks, prevent interaction
                                                  // with class appointments.
                                                  final allAreClasses =
                                                      appointments.every(
                                                    (appt) => (appt.notes ==
                                                        ScheduleAppointmentMeta
                                                            .typeClass),
                                                  );
                                                  if (isAcademicBreakOnVisibleDay &&
                                                      allAreClasses) {
                                                    return;
                                                  }

                                                  // During user "hide classes" events, disable
                                                  // interaction with class blocks (keep them visible).
                                                  if (!isAcademicBreakOnVisibleDay &&
                                                      hasHideClassEventsOnVisibleDay &&
                                                      allAreClasses) {
                                                    final allAreDisabled =
                                                        appointments.every(
                                                      (appt) =>
                                                          isFullyCoveredByAnyEvent(
                                                        innerStart:
                                                            appt.startTime,
                                                        innerEnd: appt.endTime,
                                                        events: hideClassEvents,
                                                      ),
                                                    );

                                                    if (allAreDisabled) return;
                                                  }

                                                  if (appointments.length ==
                                                          1 &&
                                                      isOverflowAppointment(
                                                        appointments.first,
                                                      )) {
                                                    await _showOverflowPicker(
                                                      appointments.first,
                                                      selectedTerm:
                                                          selectedTerm,
                                                    );
                                                    return;
                                                  }

                                                  final detailAppointments =
                                                      expandAppointmentsForDetails(
                                                          appointments);
                                                  if (detailAppointments
                                                      .isEmpty) return;
                                                  _showAppointmentsBottomSheet(
                                                    detailAppointments,
                                                    selectedTerm: selectedTerm,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
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
          );
        },
      ),
    );
  }

  void _showAppointmentsBottomSheet(
    List<Appointment> appointments, {
    required TermWindow selectedTerm,
  }) {
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
              onEditPressed: () => _handleDetailsEdit(
                appointment,
                selectedTerm: selectedTerm,
              ),
              onCancelPressed: () => _handleDetailsCancel(
                appointment,
              ),
            );
          } else {
            return ScheduleDetailsSheet(
              sheetTitle: sheetTitle,
              appointment: appointment,
              type: ScheduleDetailsType.eventDetails,
              onEditPressed: () => _handleDetailsEdit(
                appointment,
                selectedTerm: selectedTerm,
              ),
              onCancelPressed: () => _handleDetailsCancel(
                appointment,
              ),
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

  Future<void> _handleDetailsEdit(
    Appointment appointment, {
    required TermWindow selectedTerm,
  }) async {
    Navigator.of(context).pop();
    final meta = appointment.id;
    if (meta is! ScheduleAppointmentMeta) return;

    if (meta.type == ScheduleAppointmentMeta.typeEvent &&
        meta.events.isNotEmpty) {
      final updated = await ScheduleEventEditorScreen.show(
        context,
        initialEvent: meta.events.first,
        selectedTerm: selectedTerm,
      );
      if (updated == null || !mounted) return;
      await updateAcademicEvent(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated.')),
      );
      return;
    }

    if (meta.type != ScheduleAppointmentMeta.typeClass) return;
    final classMeta = _extractClassMeta(meta);
    if (classMeta == null) return;
    final initialDraft = _buildDraftFromAppointment(
      appointment: appointment,
      meta: classMeta,
    );
    final result = await ScheduleClassEditorScreen.show(
      context,
      initialDraft: initialDraft,
    );
    if (result == null || !mounted) return;

    if (result.applyScope == ClassEditApplyScope.thisClassOnly) {
      final overrideStart =
          parseTimeLabelToMinutes(result.updatedDraft.startTime);
      final overrideEnd = parseTimeLabelToMinutes(result.updatedDraft.endTime);
      if (overrideStart == null ||
          overrideEnd == null ||
          overrideEnd <= overrideStart) {
        return;
      }
      final override = ClassSlotOverride(
        id: ClassSlotOverride.buildClassSlotOverrideId(
          classSlotId: classMeta.classSlotId,
          occurrenceDate: classMeta.classOccurrenceDate,
        ),
        classSlotId: classMeta.classSlotId,
        occurrenceDate: classMeta.classOccurrenceDate,
        action: ClassSlotOverrideAction.edit,
        overrideDate: result.updatedDraft.occurrenceDate == null
            ? null
            : DateTime(
                result.updatedDraft.occurrenceDate!.year,
                result.updatedDraft.occurrenceDate!.month,
                result.updatedDraft.occurrenceDate!.day,
              ),
        overrideStartMinutes: overrideStart,
        overrideEndMinutes: overrideEnd,
        overrideMode: result.updatedDraft.mode,
        overrideVenue: result.updatedDraft.venue,
      );
      await upsertClassSlotOverride(override);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class updated for this occurrence.')),
      );
      return;
    }

    final replacement = TimetableSlot(
      classSlotId: classMeta.classSlotId,
      day: result.updatedDraft.day,
      startTime: result.updatedDraft.startTime,
      endTime: result.updatedDraft.endTime,
      mode: result.updatedDraft.mode,
      classType: result.updatedDraft.classType,
      venue: result.updatedDraft.venue,
    );
    await updateClassSlotSeriesById(
      sessionId: classMeta.classSessionId,
      termId: classMeta.classTermId,
      courseCode: classMeta.classCourseCode,
      classSlotId: classMeta.classSlotId,
      replacement: replacement,
    );
    await deleteClassSlotOverridesForClassSlotId(
      classSlotId: classMeta.classSlotId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class updated for all occurrences.')),
    );
  }

  Future<void> _handleDetailsCancel(Appointment appointment) async {
    Navigator.of(context).pop();
    final meta = appointment.id;
    if (meta is! ScheduleAppointmentMeta) return;

    if (meta.type == ScheduleAppointmentMeta.typeEvent &&
        meta.events.isNotEmpty) {
      final event = meta.events.first;
      final shouldDelete = await showConfirmDeleteDialog(
        context,
        title: 'Delete Event',
        message: 'Are you sure you want to delete this event?',
      );
      if (!shouldDelete) return;
      await deleteAcademicEvent(event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted.')),
      );
      return;
    }

    if (meta.type != ScheduleAppointmentMeta.typeClass) return;
    final classMeta = _extractClassMeta(meta);
    if (classMeta == null) return;
    final scope = await _showClassApplyScopePicker(
      title: 'Cancel Class',
      thisOnlyLabel: 'This class only',
      allLabel: 'All classes at this time',
    );
    if (scope == null) return;

    if (scope == ClassEditApplyScope.thisClassOnly) {
      final override = ClassSlotOverride(
        id: ClassSlotOverride.buildClassSlotOverrideId(
          classSlotId: classMeta.classSlotId,
          occurrenceDate: classMeta.classOccurrenceDate,
        ),
        classSlotId: classMeta.classSlotId,
        occurrenceDate: classMeta.classOccurrenceDate,
        action: ClassSlotOverrideAction.cancel,
      );
      await upsertClassSlotOverride(override);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This class occurrence cancelled.')),
      );
      return;
    }

    await deleteClassSlotSeriesById(
      sessionId: classMeta.classSessionId,
      termId: classMeta.classTermId,
      courseCode: classMeta.classCourseCode,
      classSlotId: classMeta.classSlotId,
    );
    await deleteClassSlotOverridesForClassSlotId(
      classSlotId: classMeta.classSlotId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class cancelled for all occurrences.')),
    );
  }

  Future<ClassEditApplyScope?> _showClassApplyScopePicker({
    required String title,
    required String thisOnlyLabel,
    required String allLabel,
  }) {
    return showDialog<ClassEditApplyScope>(
      context: context,
      builder: (dialogContext) {
        var selectedScope = ClassEditApplyScope.thisClassOnly;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Are you sure you want to cancel this class?'),
                  const SizedBox(height: AppSpacing.md),
                  RadioListTile<ClassEditApplyScope>(
                    value: ClassEditApplyScope.thisClassOnly,
                    groupValue: selectedScope,
                    contentPadding: EdgeInsets.zero,
                    title: Text(thisOnlyLabel),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedScope = value);
                    },
                  ),
                  RadioListTile<ClassEditApplyScope>(
                    value: ClassEditApplyScope.allClasses,
                    groupValue: selectedScope,
                    contentPadding: EdgeInsets.zero,
                    title: Text(allLabel),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedScope = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedScope),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _ClassSourceMeta? _extractClassMeta(ScheduleAppointmentMeta meta) {
    final sessionId = meta.classSessionId;
    final termId = meta.classTermId;
    final courseCode = meta.classCourseCode;
    final classSlotId = meta.classSlotId;
    final classOccurrenceDate = meta.classOccurrenceDate;
    final sourceDay = meta.classSourceDay;
    final sourceStartMinutes = meta.classSourceStartMinutes;
    final sourceEndMinutes = meta.classSourceEndMinutes;
    if (sessionId == null ||
        termId == null ||
        courseCode == null ||
        classSlotId == null ||
        classOccurrenceDate == null ||
        sourceDay == null ||
        sourceStartMinutes == null ||
        sourceEndMinutes == null) {
      return null;
    }
    return _ClassSourceMeta(
      classSessionId: sessionId,
      classTermId: termId,
      classCourseCode: courseCode,
      classSlotId: classSlotId,
      classOccurrenceDate: classOccurrenceDate,
      classSourceDay: sourceDay,
      classSourceStartMinutes: sourceStartMinutes,
      classSourceEndMinutes: sourceEndMinutes,
    );
  }

  ClassSlotDraft _buildDraftFromAppointment({
    required Appointment appointment,
    required _ClassSourceMeta meta,
  }) {
    final lines = appointment.subject.split('\n');
    final classTypeLabel =
        lines.length > 1 ? lines[1].trim().toLowerCase() : '';
    var classType = ClassType.other;
    for (final value in ClassType.values) {
      if (value.label.toLowerCase() == classTypeLabel) {
        classType = value;
        break;
      }
    }
    return ClassSlotDraft(
      classSlotId: meta.classSlotId,
      day: meta.classSourceDay,
      occurrenceDate: DateTime(
        appointment.startTime.year,
        appointment.startTime.month,
        appointment.startTime.day,
      ),
      startTime: formatTime12h(appointment.startTime),
      endTime: formatTime12h(appointment.endTime),
      mode:
          ((appointment.id as ScheduleAppointmentMeta).mode ?? 'Online').trim(),
      classType: classType,
      venue: ((appointment.id as ScheduleAppointmentMeta).venue ?? '')
              .trim()
              .isEmpty
          ? null
          : (appointment.id as ScheduleAppointmentMeta).venue?.trim(),
    );
  }

  Future<void> _showOverflowPicker(
    Appointment overflowAppointment, {
    required TermWindow selectedTerm,
  }) async {
    final hiddenItems = expandAppointmentsForDetails([overflowAppointment]);
    if (hiddenItems.isEmpty || !mounted) return;

    final selected = await showScheduleOverflowPopupMenu(
      context: context,
      tapPosition: _lastPointerGlobalPosition,
      hiddenItems: hiddenItems,
      formatAppointmentRange: formatOverflowPopupSubtitle,
    );

    if (selected == null || !mounted) return;
    _showAppointmentsBottomSheet(
      [selected],
      selectedTerm: selectedTerm,
    );
  }
}

class _ClassSourceMeta {
  const _ClassSourceMeta({
    required this.classSessionId,
    required this.classTermId,
    required this.classCourseCode,
    required this.classSlotId,
    required this.classOccurrenceDate,
    required this.classSourceDay,
    required this.classSourceStartMinutes,
    required this.classSourceEndMinutes,
  });

  final String classSessionId;
  final String classTermId;
  final String classCourseCode;
  final String classSlotId;
  final DateTime classOccurrenceDate;
  final String classSourceDay;
  final int classSourceStartMinutes;
  final int classSourceEndMinutes;
}

class _ScheduleDataSource extends CalendarDataSource {
  _ScheduleDataSource(List<Appointment> source) {
    appointments = source;
  }
}
