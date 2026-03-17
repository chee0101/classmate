import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/academic_event_store.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/models/academic_event.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/models/academic_session.dart';
import '../../core/services/task_store.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/constants/weekdays.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/services/course_store.dart';
import '../../core/builders/schedule_appointment_builder.dart';
import '../../core/models/course.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/utils/task_utils.dart';
import '../../core/utils/session_term_resolver.dart';
import '../../core/utils/term_windows.dart';
import '../../core/models/session_term_ref.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';
import '../../core/widgets/home/today_classes_card.dart';
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
                          return ValueListenableBuilder<List<TimetableEntry>>(
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
                                  .where((task) =>
                                      isInTerm(task.dueDateTime, selectedTerm))
                                  .toList();
                              final upcomingEvents = events
                                  .where(
                                    (event) =>
                                        event.sessionId == selectedSession.id &&
                                        event.termId == selectedTerm.id &&
                                        !event.endDateTime.isBefore(
                                          DateTime(
                                            now.year,
                                            now.month,
                                            now.day,
                                            0,
                                            0,
                                          ),
                                        ),
                                  )
                                  .toList(growable: false)
                                ..sort((a, b) =>
                                    a.startDateTime.compareTo(b.startDateTime));

                              final today =
                                  DateTime(now.year, now.month, now.day);
                              final weekdayOrder = weekdayNamesMondayFirst;
                              final todayName = weekdayOrder[today.weekday - 1];

                              final courseColorByCode = <String, Color>{
                                for (final c in courses.where(
                                  (c) =>
                                      c.sessionId == selectedSession.id &&
                                      c.termId == selectedTerm.id,
                                ))
                                  c.courseCode:
                                      ScheduleAppointmentBuilder.parseHexColor(
                                          c.courseColor),
                              };

                              final todayItems = timetables
                                  .where(
                                    (e) =>
                                        e.sessionId == selectedSession.id &&
                                        e.termId == selectedTerm.id,
                                  )
                                  .expand((entry) => entry.slots
                                      .where((slot) => slot.day == todayName)
                                      .map(
                                        (slot) => TodayClassItem(
                                          slot: slot,
                                          courseCode: entry.courseCode,
                                          courseColor: courseColorByCode[
                                                  entry.courseCode] ??
                                              const Color(0xFF6C4DD9),
                                        ),
                                      ))
                                  .toList(growable: false)
                                ..sort((a, b) {
                                  final aStart = parseTimeLabel12hToMinutes(
                                      a.slot.startTime);
                                  final bStart = parseTimeLabel12hToMinutes(
                                      b.slot.startTime);
                                  if (aStart == null && bStart == null)
                                    return 0;
                                  if (aStart == null) return 1;
                                  if (bStart == null) return -1;
                                  return aStart.compareTo(bStart);
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
                                      selectedSessionId: selectedSession.id,
                                      selectedTermId: selectedTerm.id,
                                      onSelectionChanged: (sessionId, termId) {
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
                                          TodayClassesCard(items: todayItems),
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
