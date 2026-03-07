import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/models/academic_session.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/models/task.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/services/task_store.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/task/task_card.dart';
import '../../core/widgets/task/task_course_filter.dart';
import '../../core/widgets/task/task_status_tabs.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  TaskStatus _selectedStatus = TaskStatus.ongoing;

  String? _selectedCourseCode; // null = All courses

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder<List<AcademicSession>>(
        valueListenable: academicSessionsNotifier,
        builder: (context, sessionsList, _) {
          final activeSession = currentAcademicSessionNotifier.value;
          final sessions = <AcademicSession>[...sessionsList];
          if (activeSession != null &&
              !sessions.any((session) => session.id == activeSession.id)) {
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
                  subtitle:
                      'Add your academic calendar to begin tracking tasks in your semester.',
                ),
              ),
            );
          }

          final now = DateTime.now();
          final refs = <({AcademicSession session, TermWindow term})>[];
          for (final session in sessions) {
            for (final term in buildTermWindows(session)) {
              refs.add((session: session, term: term));
            }
          }
          var selectedRef = refs.first;
          final current = refs.where(
            (ref) => !now.isBefore(ref.term.start) && !now.isAfter(ref.term.end),
          );
          if (current.isNotEmpty) selectedRef = current.first;

          return ValueListenableBuilder<SessionTermSelection?>(
            valueListenable: selectedSessionTermNotifier,
            builder: (context, selectedSelection, _) {
              final selectedSessionId =
                  selectedSelection?.sessionId ?? selectedRef.session.id;
              final selectedTermId =
                  selectedSelection?.termId ?? selectedRef.term.id;
              final exact = refs.where(
                (ref) =>
                    ref.session.id == selectedSessionId &&
                    ref.term.id == selectedTermId,
              );
              if (exact.isNotEmpty) selectedRef = exact.first;

              if (selectedSelection == null ||
                  selectedSelection.sessionId != selectedRef.session.id ||
                  selectedSelection.termId != selectedRef.term.id) {
                setSelectedSessionTerm(
                  sessionId: selectedRef.session.id,
                  termId: selectedRef.term.id,
                );
              }

              return ValueListenableBuilder(
                valueListenable: tasksNotifier,
                builder: (context, allTasks, _) {
              // Only show top-level tasks in the list (subtasks are shown in detail view).
              final topLevelTasks = allTasks
                  .where(
                    (task) =>
                        task.parentTaskId == null &&
                        isInTerm(task.dueDateTime, selectedRef.term),
                  )
                  .toList();

              // Build distinct course codes for the filter.
              final courseCodes = topLevelTasks
                  .map((t) => t.courseCode)
                  .toSet()
                  .toList()
                ..sort();

              final tasks = topLevelTasks.where((t) {
                final matchesStatus = t.status == _selectedStatus;
                final matchesCourse =
                    _selectedCourseCode == null || t.courseCode == _selectedCourseCode;
                return matchesStatus && matchesCourse;
              }).toList()
                ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));

              return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: TaskStatusTabs(
                  selected: _selectedStatus,
                  onChanged: (status) {
                    setState(() => _selectedStatus = status);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TaskCourseFilter(
                  courseCodes: courseCodes,
                  selectedCourseCode: _selectedCourseCode,
                  onChanged: (code) {
                    setState(() => _selectedCourseCode = code);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: tasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), 
                            child: Text(
                              'No tasks found. Looks like you\'re all caught up!',
                              style: textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            )
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.lg,
                            left: AppSpacing.lg,
                            right: AppSpacing.lg,
                          ),
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final nextSubtaskTitle =
                                _getNextSubtaskTitle(task.id, allTasks);
                            return TaskCard(
                              task: task,
                              onMarkDone: () async => _markTaskAsCompleted(task),
                              onTap: () => _navigateToTaskDetail(task),
                              nextSubtaskTitle: nextSubtaskTitle,
                            );
                          },
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

  Future<void> _markTaskAsCompleted(Task task) async {
    if (task.status == TaskStatus.completed) return;

    await updateTask(task.copyWith(status: TaskStatus.completed));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task marked as completed'),
      ),
    );
  }

  void _navigateToTaskDetail(Task task) {
    Navigator.pushNamed(
      context,
      AppRoutes.taskDetail,
      arguments: task,
    );
  }

  /// Returns the title of the nearest-due (and not yet completed) subtask,
  /// or null if there is no such subtask.
  String? _getNextSubtaskTitle(String parentTaskId, List<Task> allTasks) {
    final subtasks = allTasks
        .where((t) => t.parentTaskId == parentTaskId)
        .toList(growable: false);
    if (subtasks.isEmpty) return null;

    final remaining = subtasks
        .where((t) => t.status != TaskStatus.completed)
        .toList()
      ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));

    if (remaining.isEmpty) return null;
    return remaining.first.title;
  }
}
