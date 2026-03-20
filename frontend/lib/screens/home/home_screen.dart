import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/academic_event_store.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/models/academic_event.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/models/academic_session.dart';
import '../../core/services/task_store.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/class_slot_override_store.dart';
import '../../core/constants/weekdays.dart';
import '../../core/models/class_slot_override.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/services/course_store.dart';
import '../../core/builders/schedule_appointment_builder.dart';
import '../../core/models/course.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/utils/task_utils.dart';
import '../../core/utils/session_term_resolver.dart';
import '../../core/utils/term_windows.dart';
import '../../core/utils/event_time_utils.dart';
import '../../core/models/session_term_ref.dart';
import '../../core/utils/day_bounds_utils.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';
import '../../core/widgets/home/today_schedule_card.dart';
import '../../core/widgets/home/upcoming_events_card.dart';
import '../../core/widgets/home/upcoming_deadlines_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder<List<AcademicSession>>(
        valueListenable: academicSessionsNotifier,
        builder: (context, sessionsList, _) {
          final activeSession = currentAcademicSessionNotifier.value;

          // Build full session list, ensuring active session is included.
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

          // Build all (session, term) combinations and resolve default.
          final now = DateTime.now();
          final allTermRefs = buildAllSessionTermRefs(sessions);
          final resolvedDefaultRef =
              resolveDefaultSessionTermRef(allTermRefs, now);

          return ValueListenableBuilder<SessionTermSelection?>(
            valueListenable: selectedSessionTermNotifier,
            builder: (context, selectedSelection, _) {
              String selectedSessionId =
                  selectedSelection?.sessionId ?? resolvedDefaultRef.session.id;
              String selectedTermId =
                  selectedSelection?.termId ?? resolvedDefaultRef.term.id;

              SessionTermRef selectedRef = resolvedDefaultRef;
              for (final ref in allTermRefs) {
                if (ref.session.id == selectedSessionId &&
                    ref.term.id == selectedTermId) {
                  selectedRef = ref;
                  break;
                }
              }

              selectedSessionId = selectedRef.session.id;
              selectedTermId = selectedRef.term.id;
              final selectedSession = selectedRef.session;
              final selectedTerm = selectedRef.term;

              if (selectedSelection == null ||
                  selectedSelection.sessionId != selectedSessionId ||
                  selectedSelection.termId != selectedTermId) {
                setSelectedSessionTerm(
                  sessionId: selectedSessionId,
                  termId: selectedTermId,
                );
              }

              return ValueListenableBuilder(
                valueListenable: tasksNotifier,
                builder: (context, tasks, _) {
                  return ValueListenableBuilder<List<AcademicEvent>>(
                    valueListenable: academicEventsNotifier,
                    builder: (context, events, _) {
                      return ValueListenableBuilder<List<Course>>(
                        valueListenable: coursesNotifier,
                        builder: (context, courses, _) {
                          return ValueListenableBuilder<
                              List<ClassSlotOverride>>(
                            valueListenable: classSlotOverridesNotifier,
                            builder: (context, classOverrides, _) {
                              return ValueListenableBuilder<
                                  List<TimetableEntry>>(
                                valueListenable: timetablesNotifier,
                                builder: (context, timetables, _) {
                                  // Get upcoming tasks and filter by selected term window
                                  final allUpcomingTasks =
                                      TaskUtils.getUpcomingTasks(
                                    tasks
                                        .where((t) => t.parentTaskId == null)
                                        .toList(),
                                  );
                                  final upcomingTasks = allUpcomingTasks
                                      .where((task) => isInTerm(
                                          task.dueDateTime, selectedTerm))
                                      .toList();
                                  final upcomingEvents = events
                                      .where(
                                        (event) =>
                                            event.sessionId ==
                                                selectedSession.id &&
                                            event.termId == selectedTerm.id &&
                                            event.startDateTime.isAfter(
                                              DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                23,
                                                59,
                                                59,
                                                999,
                                              ),
                                            ),
                                      )
                                      .toList(growable: false)
                                    ..sort((a, b) => a.startDateTime
                                        .compareTo(b.startDateTime));

                                  final today =
                                      DateTime(now.year, now.month, now.day);
                                  final weekdayOrder = weekdayNamesMondayFirst;
                                  final todayName =
                                      weekdayOrder[today.weekday - 1];

                                  final overridesByOccurrenceKey =
                                      <String, ClassSlotOverride>{
                                    for (final o in classOverrides)
                                      if (o.occurrenceDate.year == today.year &&
                                          o.occurrenceDate.month ==
                                              today.month &&
                                          o.occurrenceDate.day == today.day)
                                        o.occurrenceKey: o,
                                  };

                                  final courseColorByCode = <String, Color>{
                                    for (final c in coursesForSessionAndTerm(
                                      sessionId: selectedSession.id,
                                      termId: selectedTerm.id,
                                    ))
                                      c.courseCode: ScheduleAppointmentBuilder
                                          .parseHexColor(
                                        c.courseColor,
                                      ),
                                  };

                                  final todayStart = startOfDay(today);
                                  final todayEnd = endOfDayInclusive(today);

                                  // -----------------------------
                                  // 1) Today's class items
                                  // -----------------------------
                                  final todayClassItems = timetables
                                      .where(
                                        (e) =>
                                            e.sessionId == selectedSession.id &&
                                            e.termId == selectedTerm.id,
                                      )
                                      .expand((entry) => entry.slots
                                              .where((slot) => slot.day == todayName)
                                              .map((slot) {
                                            final overrideKey = ClassSlotOverride
                                                .buildClassSlotOccurrenceKey(
                                              classSlotId: slot.classSlotId,
                                              occurrenceDate: today,
                                            );
                                            final override =
                                                overridesByOccurrenceKey[
                                                    overrideKey];

                                            if (override?.action ==
                                                ClassSlotOverrideAction.cancel) {
                                              return null;
                                            }

                                            final overrideMode =
                                                (override?.overrideMode ?? '')
                                                    .trim();
                                            final overrideVenue =
                                                (override?.overrideVenue ?? '')
                                                    .trim();

                                            final effectiveSlot = override == null
                                                ? slot
                                                : slot.copyWith(
                                                    mode: overrideMode.isEmpty
                                                        ? slot.mode
                                                        : overrideMode,
                                                    venue: overrideVenue.isEmpty
                                                        ? slot.venue
                                                        : overrideVenue,
                                                  );

                                            final startMinutes =
                                                parseTimeLabel12hToMinutes(
                                                    effectiveSlot.startTime);
                                            final endMinutes =
                                                parseTimeLabel12hToMinutes(
                                                    effectiveSlot.endTime);
                                            if (startMinutes == null ||
                                                endMinutes == null ||
                                                endMinutes <= startMinutes) {
                                              return null;
                                            }

                                            final isOnline =
                                                effectiveSlot.mode == 'Online';
                                            final venueLabel = isOnline
                                                ? 'Online'
                                                : (() {
                                                    final raw =
                                                        effectiveSlot.venue
                                                            ?.trim();
                                                    return raw == null ||
                                                            raw.isEmpty
                                                        ? null
                                                        : raw;
                                                  })();

                                            return TodayScheduleItem(
                                              type:
                                                  TodayScheduleItemType.classItem,
                                              startMinutes: startMinutes,
                                              endMinutes: endMinutes,
                                              title: entry.courseCode,
                                              color:
                                                  courseColorByCode[entry.courseCode] ??
                                                      const Color(0xFF6C4DD9),
                                              isOnline: isOnline,
                                              venueLabel: venueLabel,
                                            );
                                          }))
                                      .whereType<TodayScheduleItem>()
                                      .toList(growable: false)
                                    ..sort((a, b) {
                                      if (a.startMinutes != b.startMinutes) {
                                        return a.startMinutes.compareTo(
                                            b.startMinutes);
                                      }
                                      return a.endMinutes.compareTo(b.endMinutes);
                                    });

                                  // -----------------------------
                                  // 2) Today's event items
                                  // -----------------------------
                                  final todayEvents = events
                                      .where(
                                        (event) =>
                                            event.sessionId ==
                                                selectedSession.id &&
                                            event.termId == selectedTerm.id &&
                                            (isSameDate(event.startDateTime, today) ||
                                                isSameDate(event.endDateTime, today)) &&
                                            !event.endDateTime
                                                .isBefore(todayStart) &&
                                            !event.startDateTime
                                                .isAfter(todayEnd),
                                      )
                                      .toList(growable: false)
                                    ..sort((a, b) =>
                                        a.startDateTime.compareTo(b.startDateTime));

                                  AcademicEvent? academicBreakEvent;
                                  for (final event in todayEvents) {
                                    if (!event.isAcademicBreak) continue;
                                    if (academicBreakEvent == null ||
                                        event.startDateTime
                                            .isBefore(academicBreakEvent.startDateTime)) {
                                      academicBreakEvent = event;
                                    }
                                  }

                                  final nonAcademicEventItems = todayEvents
                                      .where((e) => !e.isAcademicBreak)
                                      .map((event) {
                                        final range =
                                            eventTimeRangeForDay(event, today);
                                        final startMinutes = range.startMinutes;
                                        final endMinutes = range.endMinutesExclusive;

                                        final venueLabel = (event
                                                    .location
                                                    ?.trim()
                                                    .isEmpty ??
                                                true)
                                            ? null
                                            : event.location!.trim();

                                        return TodayScheduleItem(
                                          type: TodayScheduleItemType.eventItem,
                                          startMinutes: startMinutes,
                                          endMinutes: endMinutes,
                                          title: event.title,
                                          color: appPrimarySwatch.shade700,
                                          isOnline: false,
                                          venueLabel: venueLabel,
                                        );
                                      })
                                      .toList(growable: false);

                                  // -----------------------------
                                  // 3) Apply academic break UI rules
                                  // -----------------------------
                                  final academicBreakTitle =
                                      academicBreakEvent?.title;

                                  // Academic break without events: show the special empty state.
                                  if (academicBreakEvent != null &&
                                      nonAcademicEventItems.isEmpty) {
                                    return Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: AppSpacing.md,
                                            right: AppSpacing.md,
                                          ),
                                          child: SessionHeader(
                                            sessions: sessions,
                                            selectedSessionId:
                                                selectedSession.id,
                                            selectedTermId:
                                                selectedTerm.id,
                                            onSelectionChanged:
                                                (sessionId, termId) {
                                              setSelectedSessionTerm(
                                                sessionId: sessionId,
                                                termId: termId,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            padding: const EdgeInsets.only(
                                              top: AppSpacing.sm,
                                              left: AppSpacing.md,
                                              right: AppSpacing.md,
                                              bottom: AppSpacing.md,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                TodayScheduleCard(
                                                  items: const [],
                                                  academicBreakTitle:
                                                      academicBreakTitle,
                                                  showAcademicBreakChip: false,
                                                ),
                                                const SizedBox(height: AppSpacing.md),
                                                UpcomingEventsCard(
                                                    events: upcomingEvents),
                                                const SizedBox(height: AppSpacing.md),
                                                UpcomingDeadlinesCard(
                                                    tasks: upcomingTasks),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  // Academic break with events: show events only.
                                  if (academicBreakEvent != null &&
                                      nonAcademicEventItems.isNotEmpty) {
                                    final scheduleItems = [...nonAcademicEventItems]
                                      ..sort((a, b) {
                                        if (a.startMinutes != b.startMinutes) {
                                          return a.startMinutes.compareTo(
                                              b.startMinutes);
                                        }
                                        return a.endMinutes.compareTo(b.endMinutes);
                                      });

                                    return Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: AppSpacing.md,
                                            right: AppSpacing.md,
                                          ),
                                          child: SessionHeader(
                                            sessions: sessions,
                                            selectedSessionId:
                                                selectedSession.id,
                                            selectedTermId: selectedTerm.id,
                                            onSelectionChanged:
                                                (sessionId, termId) {
                                              setSelectedSessionTerm(
                                                sessionId: sessionId,
                                                termId: termId,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            padding: const EdgeInsets.only(
                                              top: AppSpacing.sm,
                                              left: AppSpacing.md,
                                              right: AppSpacing.md,
                                              bottom: AppSpacing.md,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                TodayScheduleCard(
                                                  items: scheduleItems,
                                                  academicBreakTitle:
                                                      academicBreakTitle,
                                                  showAcademicBreakChip: true,
                                                ),
                                                const SizedBox(height: AppSpacing.md),
                                                UpcomingEventsCard(
                                                    events: upcomingEvents),
                                                const SizedBox(height: AppSpacing.md),
                                                UpcomingDeadlinesCard(
                                                    tasks: upcomingTasks),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  // -----------------------------
                                  // 4) Normal day: merge classes + events
                                  // -----------------------------
                                  // Compute overlap warnings for classes vs events.
                                  TodayScheduleItem _withOverlapWarning(
                                    TodayScheduleItem classItem,
                                    String overlappingEventTitle,
                                  ) {
                                    return TodayScheduleItem(
                                      type: classItem.type,
                                      startMinutes: classItem.startMinutes,
                                      endMinutes: classItem.endMinutes,
                                      title: classItem.title,
                                      color: classItem.color,
                                      isOnline: classItem.isOnline,
                                      venueLabel: classItem.venueLabel,
                                      overlapsWithEventTitle:
                                          overlappingEventTitle,
                                    );
                                  }

                                  final scheduleClassItems = todayClassItems
                                      .map((classItem) {
                                    final overlappingEvents =
                                        nonAcademicEventItems.where((e) {
                                      return classItem.startMinutes <
                                              e.endMinutes &&
                                          e.startMinutes <
                                              classItem.endMinutes;
                                    }).toList(growable: false)
                                          ..sort((a, b) =>
                                              a.startMinutes.compareTo(b.startMinutes));

                                    if (overlappingEvents.isEmpty) {
                                      return classItem;
                                    }

                                    return _withOverlapWarning(
                                      classItem,
                                      overlappingEvents.first.title,
                                    );
                                  }).toList(growable: false);

                                  final scheduleItems = [
                                    ...nonAcademicEventItems,
                                    ...scheduleClassItems,
                                  ]..sort((a, b) {
                                      if (a.startMinutes != b.startMinutes) {
                                        return a.startMinutes
                                            .compareTo(b.startMinutes);
                                      }
                                      // Tie-break: events first.
                                      final aPri = a.type ==
                                              TodayScheduleItemType.eventItem
                                          ? 0
                                          : 1;
                                      final bPri = b.type ==
                                              TodayScheduleItemType.eventItem
                                          ? 0
                                          : 1;
                                      if (aPri != bPri) return aPri.compareTo(bPri);
                                      return a.endMinutes.compareTo(b.endMinutes);
                                    });

                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: AppSpacing.md,
                                          right: AppSpacing.md,
                                        ),
                                        child: SessionHeader(
                                          sessions: sessions,
                                          selectedSessionId:
                                              selectedSession.id,
                                          selectedTermId: selectedTerm.id,
                                          onSelectionChanged:
                                              (sessionId, termId) {
                                            setSelectedSessionTerm(
                                              sessionId: sessionId,
                                              termId: termId,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.only(
                                            top: AppSpacing.sm,
                                            left: AppSpacing.md,
                                            right: AppSpacing.md,
                                            bottom: AppSpacing.md,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              TodayScheduleCard(
                                                items: scheduleItems,
                                                academicBreakTitle: null,
                                                showAcademicBreakChip: false,
                                              ),
                                              const SizedBox(
                                                  height: AppSpacing.md),
                                              UpcomingEventsCard(
                                                  events: upcomingEvents),
                                              const SizedBox(
                                                  height: AppSpacing.md),
                                              UpcomingDeadlinesCard(
                                                  tasks: upcomingTasks),
                                            ],
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
          );
        },
      ),
    );
  }
}
