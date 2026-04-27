import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/models/academic_session.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/models/task.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/task_store.dart';
import '../../core/utils/course_display.dart';
import '../../core/utils/term_windows.dart';
import '../../core/utils/task_utils.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/animated_segmented_switch.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/common/session_term_context_label.dart';
import '../../core/widgets/home/home_next_action_card.dart';
import '../../core/widgets/home/home_overview_cards.dart';
import '../../core/widgets/home/home_workload_chart_card.dart';
import '../../core/widgets/task/task_card.dart';
import '../../core/widgets/task/task_course_filter.dart';
import '../add/add_new_screen.dart' show AddType;

class _WeekWorkloadBucket {
  const _WeekWorkloadBucket({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

List<_WeekWorkloadBucket> _next4WeekWorkloadBuckets({
  required List<Task> pendingTasks,
  required TermWindow selectedTerm,
  required DateTime now,
}) {
  final termStart = DateTime(
    selectedTerm.start.year,
    selectedTerm.start.month,
    selectedTerm.start.day,
  );
  final termEnd = DateTime(
    selectedTerm.end.year,
    selectedTerm.end.month,
    selectedTerm.end.day,
  );
  final today = DateTime(now.year, now.month, now.day);
  if (today.isAfter(termEnd)) return const <_WeekWorkloadBucket>[];

  final anchorDay = today.isBefore(termStart) ? termStart : today;
  final baseWeekIndex = anchorDay.difference(termStart).inDays ~/ 7;
  final buckets = <_WeekWorkloadBucket>[];

  for (var i = 0; i < 4; i++) {
    final weekIndex = baseWeekIndex + i;
    final weekStart = termStart.add(Duration(days: weekIndex * 7));
    if (weekStart.isAfter(termEnd)) break;
    final rawWeekEnd = weekStart.add(const Duration(days: 6));
    final weekEnd = rawWeekEnd.isAfter(termEnd) ? termEnd : rawWeekEnd;
    final count = pendingTasks.where((task) {
      final due = DateTime(
        task.dueDateTime.year,
        task.dueDateTime.month,
        task.dueDateTime.day,
      );
      return !due.isBefore(weekStart) && !due.isAfter(weekEnd);
    }).length;

    buckets.add(
      _WeekWorkloadBucket(
        label: 'W${weekIndex + 1}',
        count: count,
      ),
    );
  }

  return buckets;
}

String _busiestWeekLabel(List<_WeekWorkloadBucket> buckets) {
  if (buckets.isEmpty) return 'Week -';
  var bestIndex = 0;
  for (var i = 1; i < buckets.length; i++) {
    if (buckets[i].count > buckets[bestIndex].count) {
      bestIndex = i;
    }
  }
  return 'Peak: ${buckets[bestIndex].label}';
}

int _busiestWeekCount(List<_WeekWorkloadBucket> buckets) {
  if (buckets.isEmpty) return 0;
  final counts = buckets.map((b) => b.count).toList(growable: false)..sort();
  return counts.last;
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

enum _TaskViewMode { tasks, insights }

class _TaskScreenState extends State<TaskScreen> {
  TaskStatus _selectedStatus = TaskStatus.ongoing;
  _TaskViewMode _selectedViewMode = _TaskViewMode.tasks;

  String? _selectedCourseCode; // null = All courses

  int? _lastRebuildMinute;

  // Ensures overdue status updates as time passes.
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    // Rebuild occasionally; 1 tick/frame is too frequent.
    // Throttle by only rebuilding when the minute changes.
    final now = DateTime.now();
    final shouldRebuild =
        (_lastRebuildMinute == null) || now.minute != _lastRebuildMinute;
    if (!shouldRebuild) return;
    _lastRebuildMinute = now.minute;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

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
                padding: const EdgeInsets.all(AppSpacing.md),
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
              return ValueListenableBuilder(
                valueListenable: coursesNotifier,
                builder: (context, _, __) {
              final termCourses = coursesForSessionAndTerm(
                sessionId: selectedRef.session.id,
                termId: selectedRef.term.id,
              );
              // Only show top-level tasks in the list (subtasks are shown in detail view).
              final topLevelTasks = allTasks
                  .where(
                    (task) =>
                        task.parentTaskId == null &&
                        isInTerm(task.dueDateTime, selectedRef.term),
                  )
                  .toList();
              final pendingTasks = topLevelTasks
                  .where((t) =>
                      TaskUtils.effectiveStatus(t) != TaskStatus.completed)
                  .toList(growable: false)
                ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));
              final overdueTasks = pendingTasks
                  .where((t) => TaskUtils.effectiveStatus(t) == TaskStatus.overdue)
                  .toList(growable: false)
                ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));
              final nextRecommendedTask = overdueTasks.isNotEmpty
                  ? overdueTasks.first
                  : (pendingTasks.isNotEmpty ? pendingTasks.first : null);
              final workloadBuckets = _next4WeekWorkloadBuckets(
                pendingTasks: pendingTasks,
                selectedTerm: selectedRef.term,
                now: now,
              );
              final busiestWeekLabel = _busiestWeekLabel(workloadBuckets);
              final busiestWeekCount = _busiestWeekCount(workloadBuckets);
              final weekCounts = workloadBuckets
                  .map((b) => b.count)
                  .toList(growable: false);
              final weekLabels = workloadBuckets
                  .map((b) => b.label)
                  .toList(growable: false);

              // Build distinct display course codes for the filter.
              final courseCodes = topLevelTasks
                  .map((t) => displayCourseCodeForTask(t, termCourses))
                  .toSet()
                  .toList()
                ..sort();

              final tasks = topLevelTasks.where((t) {
                final matchesStatus =
                    TaskUtils.effectiveStatus(t) == _selectedStatus;
                final displayCode =
                    displayCourseCodeForTask(t, termCourses);
                final matchesCourse =
                    _selectedCourseCode == null ||
                    displayCode == _selectedCourseCode;
                return matchesStatus && matchesCourse;
              }).toList()
                ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      0,
                    ),
                    child: AnimatedSegmentedSwitch<_TaskViewMode>(
                      value: _selectedViewMode,
                      onChanged: (value) {
                        setState(() => _selectedViewMode = value);
                      },
                      options: const [
                        SegmentedSwitchOption<_TaskViewMode>(
                          value: _TaskViewMode.tasks,
                          label: 'Tasks',
                        ),
                        SegmentedSwitchOption<_TaskViewMode>(
                          value: _TaskViewMode.insights,
                          label: 'Insights',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: _selectedViewMode == _TaskViewMode.tasks
                        ? CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: SessionTermContextLabel(
                                    sessionName: selectedRef.session.name,
                                    termLabel: selectedRef.term.label,
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: AppSpacing.sm),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: _buildStatusChipRow(),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: AppSpacing.sm),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: TaskCourseFilter(
                                    courseCodes: courseCodes,
                                    selectedCourseCode: _selectedCourseCode,
                                    onChanged: (code) {
                                      setState(() => _selectedCourseCode = code);
                                    },
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: AppSpacing.sm),
                              ),
                              if (tasks.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                      ),
                                      child: Text(
                                        'No tasks found. Looks like you\'re all caught up!',
                                        style: textTheme.bodyLarge,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpacing.md,
                                    right: AppSpacing.md,
                                    bottom: AppSpacing.md,
                                  ),
                                  sliver: SliverList.separated(
                                    itemCount: tasks.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (context, index) {
                                      final task = tasks[index];
                                      final nextSubtaskTitle =
                                          _getNextSubtaskTitle(task.id, allTasks);
                                      return TaskCard(
                                        task: task,
                                        onMarkDone: () async =>
                                            _markTaskAsCompleted(task),
                                        onTap: () => _navigateToTaskDetail(task),
                                        nextSubtaskTitle: nextSubtaskTitle,
                                        courses: termCourses,
                                      );
                                    },
                                  ),
                                ),
                            ],
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.only(
                              top: 0,
                              left: AppSpacing.md,
                              right: AppSpacing.md,
                              bottom: AppSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SessionTermContextLabel(
                                  sessionName: selectedRef.session.name,
                                  termLabel: selectedRef.term.label,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                HomeOverviewCards(
                                  pendingCount: pendingTasks.length,
                                  overdueCount: overdueTasks.length,
                                  busiestWeekLabel: busiestWeekLabel,
                                  busiestWeekCount: busiestWeekCount,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                HomeNextActionCard(
                                  nextTask: nextRecommendedTask,
                                  onOpenTask: () {
                                    final task = nextRecommendedTask;
                                    if (task == null) return;
                                    _navigateToTaskDetail(task);
                                  },
                                  onAddTask: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.addNew,
                                      arguments: AddType.task,
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                HomeWorkloadChartCard(
                                  weekLabels: weekLabels,
                                  weekCounts: weekCounts,
                                ),
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
      ),
    );
  }

  Widget _buildStatusChipRow() {
    final outlineColor = appPrimarySwatch.shade600.withValues(alpha: 0.55);
    final selectedFill = appPrimarySwatch.shade600.withValues(alpha: 0.16);

    return Row(
      children: [
        Expanded(
          child: _buildStatusChip(
            label: 'Ongoing',
            status: TaskStatus.ongoing,
            outlineColor: outlineColor,
            selectedFill: selectedFill,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatusChip(
            label: 'Overdue',
            status: TaskStatus.overdue,
            outlineColor: outlineColor,
            selectedFill: selectedFill,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatusChip(
            label: 'Complete',
            status: TaskStatus.completed,
            outlineColor: outlineColor,
            selectedFill: selectedFill,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip({
    required String label,
    required TaskStatus status,
    required Color outlineColor,
    required Color selectedFill,
  }) {
    return ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      selected: _selectedStatus == status,
      side: BorderSide(color: outlineColor),
      backgroundColor: Colors.white,
      selectedColor: selectedFill,
      labelStyle: TextStyle(
        color: appPrimarySwatch.shade700,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (_) {
        setState(() => _selectedStatus = status);
      },
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
