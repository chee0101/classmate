import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/course.dart';
import '../../core/models/task.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/extraction_job_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/services/task_store.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/utils/task_extraction_json.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/common/label_chip.dart';
import '../../core/widgets/common/white_card.dart';
import '../../core/widgets/task/task_edit_bottom_sheet.dart';

class ReviewExtractedTasksScreen extends StatefulWidget {
  const ReviewExtractedTasksScreen({
    super.key,
    required this.responseJson,
  });

  final String responseJson;

  @override
  State<ReviewExtractedTasksScreen> createState() =>
      _ReviewExtractedTasksScreenState();
}

class _ReviewExtractedTasksScreenState extends State<ReviewExtractedTasksScreen> {
  ParsedTaskExtractionEnvelope? _parsed;
  late List<ParsedExtractedTask> _tasks;
  final ScrollController _contentScrollController = ScrollController();
  final Set<int> _expandedTaskIndexes = <int>{};
  final Set<int> _selectedTaskIndexes = <int>{};
  final Map<int, Set<int>> _selectedSubtaskIndexesByTask = <int, Set<int>>{};
  bool _showSaveBarShadow = false;
  bool _saving = false;

  bool get _hasSelectedTasksMissingCourseCode {
    for (var i = 0; i < _tasks.length; i++) {
      if (!_selectedTaskIndexes.contains(i)) continue;
      if (_tasks[i].courseCode.trim().isEmpty) return true;
    }
    return false;
  }

  AcademicSession? get _selectedSession {
    final selection = selectedSessionTermNotifier.value;
    if (selection == null) return null;
    for (final session in academicSessionsNotifier.value) {
      if (session.id == selection.sessionId) return session;
    }
    final current = currentAcademicSessionNotifier.value;
    if (current != null && current.id == selection.sessionId) {
      return current;
    }
    return null;
  }

  DateTime _clampToSelectedSession(DateTime dt) {
    final session = _selectedSession;
    if (session == null) return dt;
    if (dt.isBefore(session.startDate)) return session.startDate;
    if (dt.isAfter(session.endDate)) return session.endDate;
    return dt;
  }

  Future<bool> _confirmDiscardReview() async {
    if (_saving) return false;
    return showConfirmDialog(
      context,
      title: 'Discard extracted tasks?',
      message:
          'If you leave now, reviewed extracted tasks will not be saved and will be lost.',
      cancelText: 'Stay',
      confirmText: 'Discard and leave',
      destructive: true,
    );
  }

  @override
  void initState() {
    super.initState();
    _parsed = tryParseTaskExtractionEnvelope(widget.responseJson);
    _tasks =
        _parsed == null
            ? <ParsedExtractedTask>[]
            : List<ParsedExtractedTask>.from(_parsed!.tasks);
    for (var i = 0; i < _tasks.length; i++) {
      _selectedTaskIndexes.add(i);
      _selectedSubtaskIndexesByTask[i] = <int>{
        for (var j = 0; j < _tasks[i].subtasks.length; j++) j,
      };
      if (_tasks[i].subtasks.isNotEmpty) {
        _expandedTaskIndexes.add(i);
      }
    }
    _contentScrollController.addListener(_updateSaveBarShadow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSaveBarShadow());
  }

  @override
  void dispose() {
    _contentScrollController.removeListener(_updateSaveBarShadow);
    _contentScrollController.dispose();
    super.dispose();
  }

  void _updateSaveBarShadow() {
    if (!_contentScrollController.hasClients) return;
    final position = _contentScrollController.position;
    final shouldShow =
        position.maxScrollExtent > 0 &&
        position.pixels < (position.maxScrollExtent - 1);
    if (shouldShow == _showSaveBarShadow) return;
    setState(() {
      _showSaveBarShadow = shouldShow;
    });
  }

  DateTime _resolvedDueDateTime(DateTime? candidate, {DateTime? fallback}) {
    if (candidate != null) return candidate;
    if (fallback != null) return fallback;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59);
  }

  String _dueLabel(DateTime? dt) {
    if (dt == null) return 'Due: Not set';
    return 'Due: ${formatRelativeDueDate(dt)}, ${formatTime12h(dt)}';
  }

  Course? _courseByCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final selection = selectedSessionTermNotifier.value;
    if (selection != null) {
      for (final course in coursesNotifier.value) {
        if (course.sessionId == selection.sessionId &&
            course.termId == selection.termId &&
            course.courseCode.trim().toUpperCase() == normalized) {
          return course;
        }
      }
    }
    for (final course in coursesNotifier.value) {
      if (course.courseCode.trim().toUpperCase() == normalized) {
        return course;
      }
    }
    return null;
  }

  Color _colorFromCourseHex(String hex) {
    final parsed = int.tryParse(hex.replaceFirst('#', '0xFF'));
    return Color(parsed ?? appPrimarySwatch.shade700.toARGB32());
  }

  Future<void> _editTask(int taskIndex) async {
    if (taskIndex < 0 || taskIndex >= _tasks.length) return;
    final parsed = _tasks[taskIndex];
    final matchedCourse = _courseByCode(parsed.courseCode);
    final draft = Task(
      id: 'draft-parent-$taskIndex',
      courseId: matchedCourse?.id,
      courseCode: parsed.courseCode,
      courseColor: matchedCourse == null
          ? appPrimarySwatch.shade700
          : _colorFromCourseHex(matchedCourse.courseColor),
      title: parsed.title,
      description: parsed.note,
      dueDateTime: _resolvedDueDateTime(parsed.dueDateTime),
      status: TaskStatus.ongoing,
    );
    final updated = await TaskEditBottomSheet.show(
      context,
      task: draft,
      sheetTitle: 'Edit Task',
      scopeSessionId: selectedSessionTermNotifier.value?.sessionId,
      scopeTermId: selectedSessionTermNotifier.value?.termId,
      minDueDateTime: _selectedSession?.startDate,
      maxDueDateTime: _selectedSession?.endDate,
    );
    if (updated == null || !mounted) return;
    setState(() {
      parsed.title = updated.title;
      parsed.note = updated.description;
      parsed.dueDateTime = updated.dueDateTime;
      parsed.courseCode = updated.courseCode;
    });
  }

  Future<void> _editSubtask(
    ParsedExtractedTask parent,
    ParsedExtractedSubtask subtask,
  ) async {
    final matchedCourse = _courseByCode(parent.courseCode);
    final draft = Task(
      id: 'draft-sub-${subtask.title}',
      parentTaskId: 'draft-parent',
      courseId: matchedCourse?.id,
      courseCode: parent.courseCode,
      courseColor: matchedCourse == null
          ? appPrimarySwatch.shade700
          : _colorFromCourseHex(matchedCourse.courseColor),
      title: subtask.title,
      description: subtask.note,
      dueDateTime: _resolvedDueDateTime(
        subtask.dueDateTime,
        fallback: parent.dueDateTime,
      ),
      status: TaskStatus.ongoing,
    );
    final updated = await TaskEditBottomSheet.show(
      context,
      task: draft,
      sheetTitle: 'Edit Subtask',
      isSubtask: true,
      scopeSessionId: selectedSessionTermNotifier.value?.sessionId,
      scopeTermId: selectedSessionTermNotifier.value?.termId,
      minDueDateTime: _selectedSession?.startDate,
      maxDueDateTime: _selectedSession?.endDate,
      parentDueDateTime: _resolvedDueDateTime(parent.dueDateTime),
    );
    if (updated == null || !mounted) return;
    setState(() {
      subtask.title = updated.title;
      subtask.note = updated.description;
      subtask.dueDateTime = updated.dueDateTime;
    });
  }

  Future<void> _saveTasks() async {
    if (_saving || _hasSelectedTasksMissingCourseCode) return;
    setState(() => _saving = true);
    try {
      var savedCount = 0;
      for (var taskIndex = 0; taskIndex < _tasks.length; taskIndex++) {
        if (!_selectedTaskIndexes.contains(taskIndex)) continue;
        final task = _tasks[taskIndex];
        final matchedCourse = _courseByCode(task.courseCode);
        final resolvedCourseColor = matchedCourse == null
            ? appPrimarySwatch.shade700
            : _colorFromCourseHex(matchedCourse.courseColor);
        final parentDue = _clampToSelectedSession(
          _resolvedDueDateTime(task.dueDateTime),
        );
        final parent = Task(
          id: 'tmp-parent-$taskIndex',
          courseId: matchedCourse?.id,
          courseCode: task.courseCode,
          courseColor: resolvedCourseColor,
          title: task.title.trim(),
          description: task.note?.trim().isEmpty ?? true ? null : task.note!.trim(),
          dueDateTime: parentDue,
          status: TaskStatus.ongoing,
        );
        final parentId = await addTask(parent);
        if (parentId == null) continue;
        savedCount += 1;

        final selectedSubtasks =
            _selectedSubtaskIndexesByTask[taskIndex] ?? const <int>{};
        for (var subIndex = 0; subIndex < task.subtasks.length; subIndex++) {
          if (!selectedSubtasks.contains(subIndex)) continue;
          final subtask = task.subtasks[subIndex];
          final subDue = _clampToSelectedSession(
            _resolvedDueDateTime(
              subtask.dueDateTime,
              fallback: parentDue,
            ),
          );
          final resolvedSubDue = subDue.isAfter(parentDue) ? parentDue : subDue;
          final child = Task(
            id: 'tmp-child-$taskIndex-$subIndex',
            courseId: matchedCourse?.id,
            courseCode: task.courseCode,
            courseColor: resolvedCourseColor,
            title: subtask.title.trim(),
            description:
                subtask.note?.trim().isEmpty ?? true ? null : subtask.note!.trim(),
            dueDateTime: resolvedSubDue,
            status: TaskStatus.ongoing,
            parentTaskId: parentId,
          );
          final subId = await addTask(child);
          if (subId != null) savedCount += 1;
        }
      }

      dismissExtractionJobCard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $savedCount task(s).')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parsed == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Task')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not read extracted task data.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscardReview();
        if (!shouldLeave || !context.mounted) return;
        dismissExtractionJobCard();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Task'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldLeave = await _confirmDiscardReview();
              if (!shouldLeave || !context.mounted) return;
              dismissExtractionJobCard();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Extracted Tasks',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Review what ClassMate detected and edit if needed before saving.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: appPrimarySwatch.shade700),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _contentScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _contentScrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_tasks.isEmpty)
                      WhiteCard(
                        child: Text(
                          'No tasks detected from this extraction.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...List.generate(_tasks.length, (taskIndex) {
                        final task = _tasks[taskIndex];
                        final expanded = _expandedTaskIndexes.contains(taskIndex);
                        final taskSelected = _selectedTaskIndexes.contains(taskIndex);
                        final selectedSubtasks =
                            _selectedSubtaskIndexesByTask[taskIndex] ?? const <int>{};

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: WhiteCard(
                            padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.sm),
                            borderRadius: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: taskSelected,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked ?? false) {
                                            _selectedTaskIndexes.add(taskIndex);
                                          } else {
                                            _selectedTaskIndexes.remove(taskIndex);
                                          }
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _editTask(taskIndex),
                                          borderRadius: BorderRadius.circular(10),
                                          splashColor: appPrimarySwatch.shade100.withValues(alpha: 0.45),
                                          highlightColor: appPrimarySwatch.shade100.withValues(alpha: 0.25),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: AppSpacing.xs,
                                              right: AppSpacing.xs,
                                              bottom: AppSpacing.xs,
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: AppSpacing.xs,
                                                ),
                                                child: task.courseCode.trim().isNotEmpty
                                                    ? LabelChip(
                                                        label: task.courseCode,
                                                        color: (() {
                                                          final matchedCourse =
                                                              _courseByCode(task.courseCode);
                                                          return matchedCourse ==
                                                                  null
                                                              ? appPrimarySwatch.shade700
                                                              : _colorFromCourseHex(
                                                                  matchedCourse
                                                                      .courseColor,
                                                                );
                                                        })(),
                                                      )
                                                    : const LabelChip(
                                                        label: 'COURSE REQUIRED',
                                                        background: Color(0xFFFFE5E5),
                                                        foreground: Color(0xFFD32F2F),
                                                      ),
                                              ),
                                              Text(
                                                task.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _dueLabel(task.dueDateTime),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: appPrimarySwatch.shade700,
                                                    ),
                                              ),
                                              if ((task.note ?? '').trim().isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  task.note!.trim(),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey.shade700,
                                                      ),
                                                ),
                                              ],
                                              if (task.courseCode.trim().isEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Add/select a course before saving this task.',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.red.shade700,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                ),
                                              ],
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                    left: AppSpacing.xs,
                                                    right: AppSpacing.xs,
                                                  ),
                                                  child: Icon(
                                                    Icons.arrow_forward_ios_rounded,
                                                    size: 18,
                                                    color: appPrimarySwatch.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (task.subtasks.isNotEmpty)
                                      IconButton(
                                        tooltip: expanded ? 'Collapse' : 'Expand',
                                        onPressed: () {
                                          setState(() {
                                            if (expanded) {
                                              _expandedTaskIndexes.remove(taskIndex);
                                            } else {
                                              _expandedTaskIndexes.add(taskIndex);
                                            }
                                          });
                                        },
                                        icon: Icon(
                                          expanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          color: appPrimarySwatch.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                                if (expanded && task.subtasks.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  ...List.generate(task.subtasks.length, (subIndex) {
                                    final subtask = task.subtasks[subIndex];
                                    final selected =
                                        taskSelected &&
                                        selectedSubtasks.contains(subIndex);
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: AppSpacing.md,
                                        right: AppSpacing.sm,
                                        bottom: AppSpacing.sm,
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: selected,
                                            onChanged:
                                                taskSelected
                                                    ? (checked) {
                                                      setState(() {
                                                        final set =
                                                            _selectedSubtaskIndexesByTask[taskIndex] ??
                                                            <int>{};
                                                        if (checked ?? false) {
                                                          set.add(subIndex);
                                                        } else {
                                                          set.remove(subIndex);
                                                        }
                                                        _selectedSubtaskIndexesByTask[taskIndex] =
                                                            set;
                                                      });
                                                    }
                                                    : null,
                                          ),
                                          Expanded(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => _editSubtask(task, subtask),
                                                borderRadius: BorderRadius.circular(10),
                                                splashColor: appPrimarySwatch.shade100.withValues(alpha: 0.45),
                                                highlightColor: appPrimarySwatch.shade100.withValues(alpha: 0.25),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                    vertical: AppSpacing.xs,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                    Text(
                                                      subtask.title,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _dueLabel(subtask.dueDateTime),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                appPrimarySwatch.shade700,
                                                          ),
                                                    ),
                                                    if ((subtask.note ?? '')
                                                        .trim()
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        subtask.note!.trim(),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color:
                                                                  Colors.grey.shade700,
                                                            ),
                                                      ),
                                                    ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow:
                  _showSaveBarShadow
                      ? const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: Offset(0, -4),
                        ),
                      ]
                      : const [],
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_hasSelectedTasksMissingCourseCode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        'Please add a course for selected tasks before saving.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (_saving || _hasSelectedTasksMissingCourseCode) ? null : _saveTasks,
                      child:
                          _saving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                              : const Text('Save Tasks'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
