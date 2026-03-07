import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/models/academic_session.dart';
import '../../core/services/task_store.dart';
import '../../core/utils/task_utils.dart';
import '../../core/utils/term_windows.dart';
import '../../core/models/session_term_ref.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';
import '../../core/widgets/home/today_classes_card.dart';
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

          // Build all (session, term) combinations.
          final now = DateTime.now();
          final allTermRefs = <SessionTermRef>[];
          for (final session in sessions) {
            final windows = buildTermWindows(session);
            for (final term in windows) {
              allTermRefs.add(SessionTermRef(session: session, term: term));
            }
          }

          // Pick default (session, term):
          SessionTermRef? defaultRef;

          // 1) Prefer a term where today is within the window
          for (final ref in allTermRefs) {
            if (!now.isBefore(ref.term.start) && !now.isAfter(ref.term.end)) {
              defaultRef = ref;
              break;
            }
          }

          // 2) If none, choose the nearest future term
          if (defaultRef == null) {
            Duration? minFuture;
            for (final ref in allTermRefs) {
              if (ref.term.start.isAfter(now)) {
                final diff = ref.term.start.difference(now);
                if (minFuture == null || diff < minFuture) {
                  minFuture = diff;
                  defaultRef = ref;
                }
              }
            }
          }

          // 3) If still none, choose the nearest past term
          defaultRef ??= () {
            Duration? minPast;
            SessionTermRef? best;
            for (final ref in allTermRefs) {
              if (ref.term.end.isBefore(now)) {
                final diff = now.difference(ref.term.end);
                if (minPast == null || diff < minPast) {
                  minPast = diff;
                  best = ref;
                }
              }
            }
            return best ?? allTermRefs.first;
          }();
          final resolvedDefaultRef = defaultRef;

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
              // Get upcoming tasks and filter by selected term window
              final allUpcomingTasks = TaskUtils.getUpcomingTasks(
                tasks.where((t) => t.parentTaskId == null).toList(),
              );
              final upcomingTasks = allUpcomingTasks.where((task) {
                return isInTerm(task.dueDateTime, selectedTerm);
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
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
                        top: AppSpacing.md,
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        bottom: AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TodayClassesCard(hasClasses: false),
                          const SizedBox(height: AppSpacing.lg),
                          UpcomingDeadlinesCard(tasks: upcomingTasks),
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
      ),
    );
  }
}
