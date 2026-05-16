import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/weekdays.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/class_type.dart';
import '../../core/models/session_term_ref.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/utils/course_display.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/utils/session_term_resolver.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/add/add_course_dialog.dart';
import '../../core/widgets/add/class_form.dart';
import '../../core/widgets/common/add_new_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';
import '../../core/widgets/schedule/class_slot_sheet.dart';
import '../../core/widgets/common/animated_segmented_switch.dart';
import '../../core/widgets/common/label_chip.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/timetable/timetable_course_card.dart';
import '../../core/constants/routes.dart';
import '../extract/auto_extract_screen.dart';
import '../schedule/class_slot_editor_screen.dart';
import '../../core/models/course.dart';

class TimetablesScreen extends StatefulWidget {
  const TimetablesScreen({super.key});

  @override
  State<TimetablesScreen> createState() => _TimetablesScreenState();
}

class _TimetablesScreenState extends State<TimetablesScreen> {
  _TimetableViewMode _viewMode = _TimetableViewMode.byDay;

  bool _sameTimetableSlot(TimetableSlot a, TimetableSlot b) {
    final aId = (a.classSlotId).trim();
    final bId = (b.classSlotId).trim();
    if (aId.isNotEmpty && bId.isNotEmpty) return aId == bId;

    return a.day.trim() == b.day.trim() &&
        a.startTime.trim() == b.startTime.trim() &&
        a.endTime.trim() == b.endTime.trim() &&
        a.mode.trim() == b.mode.trim() &&
        a.classType == b.classType &&
        (a.venue ?? '').trim() == (b.venue ?? '').trim();
  }

  Future<void> _confirmAndDeleteSingleSlot({
    required TimetableEntry entry,
    required TimetableSlot slot,
  }) async {
    final shouldDelete = await showConfirmDeleteDialog(
      context,
      title: 'Delete class slot',
      message:
          'Delete class for ${entry.courseCode} on ${slot.day} (${slot.startTime} – ${slot.endTime})?',
    );

    if (!shouldDelete) return;

    final nextSlots = entry.slots
        .where((s) => !_sameTimetableSlot(s, slot))
        .toList(growable: false);

    if (nextSlots.isEmpty) {
      await deleteTimetableEntry(entry.id);
      return;
    }

    await updateTimetableEntry(
      id: entry.id,
      sessionId: entry.sessionId,
      termId: entry.termId,
      courseCode: entry.courseCode,
      slots: nextSlots,
    );
  }

  List<String> _sortedDays(Iterable<String> days) {
    final sorted = days.toList(growable: false);
    sorted.sort((a, b) {
      final ai = weekdayOrderFromString(a);
      final bi = weekdayOrderFromString(b);
      if (ai == 99 && bi == 99) return a.compareTo(b);
      if (ai == 99) return 1;
      if (bi == 99) return -1;
      return ai.compareTo(bi);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Timetable'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (currentAcademicSessionNotifier.value != null)
              IconButton(
                tooltip: 'Import from file',
                icon: const Icon(Icons.upload_file_outlined),
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.autoExtract,
                    arguments: AutoExtractType.timetable,
                  );
                },
              ),
          ],
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
                    title: 'No academic session',
                    subtitle:
                        'Set up an academic session first to manage timetable slots',
                    buttonText: 'Add session',
                    icon: Icons.calendar_today_outlined,
                    onPressed: () {
                      AddNewBottomSheet.show(context);
                    },
                  ),
                ),
              );
            }

            final now = DateTime.now();
            final allTermRefs = buildAllSessionTermRefs(sessions);
            final resolvedDefaultRef =
                resolveDefaultSessionTermRef(allTermRefs, now);

            return ValueListenableBuilder<SessionTermSelection?>(
              valueListenable: selectedSessionTermNotifier,
              builder: (context, selection, _) {
                String selectedSessionId =
                    selection?.sessionId ?? resolvedDefaultRef.session.id;
                String selectedTermId =
                    selection?.termId ?? resolvedDefaultRef.term.id;

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
                String semesterName =
                    selectedTermId == 'sem1' ? 'Semester 1' : 'Semester 2';
                final selectedSession = selectedRef.session;
                final selectedTerm = selectedRef.term;

                if (selection == null ||
                    selection.sessionId != selectedSessionId ||
                    selection.termId != selectedTermId) {
                  setSelectedSessionTerm(
                    sessionId: selectedSessionId,
                    termId: selectedTermId,
                  );
                }
                return ValueListenableBuilder<List<TimetableEntry>>(
                  valueListenable: timetablesNotifier,
                  builder: (context, entries, _) {
                    final header = Padding(
                      padding: const EdgeInsets.only(
                        top: 0,
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        bottom: AppSpacing.sm,
                      ),
                      child: SessionHeader(
                        sessions: sessions,
                        selectedSessionId: selectedSessionId,
                        selectedTermId: selectedTermId,
                        onSelectionChanged: (sessionId, termId) {
                          setSelectedSessionTerm(
                            sessionId: sessionId,
                            termId: termId,
                          );
                        },
                      ),
                    );

                    if (entries
                        .where(
                          (e) =>
                              e.sessionId == selectedSessionId &&
                              e.termId == selectedTermId,
                        )
                        .isEmpty) {
                      return Stack(
                        children: [
                          Column(
                            children: [
                              header,
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: EmptyStateCard(
                                title: 'No timetable added',
                                subtitle:
                                    'Add class slots for courses in Academic Session ${activeSession?.name} $semesterName.',
                                buttonText: 'Add timetable',
                                icon: Icons.access_time_outlined,
                                onPressed: () => _openEditor(
                                  selectedSession: selectedSession,
                                  selectedTerm: selectedTerm,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ValueListenableBuilder<List<Course>>(
                      valueListenable: coursesNotifier,
                      builder: (context, courses, _) {
                        final termCourses = courses
                            .where(
                              (c) =>
                                  c.sessionId == selectedSessionId &&
                                  c.termId == selectedTermId,
                            )
                            .toList(growable: false);

                        final filtered = entries
                            .where(
                              (e) =>
                                  e.sessionId == selectedSessionId &&
                                  e.termId == selectedTermId,
                            )
                            .toList(growable: false);

                        final dayBuckets = <String, List<_DayCourseSlot>>{};
                        for (final entry in filtered) {
                          final color = displayCourseColorForTimetableEntry(
                              entry, termCourses);
                          final displayCode =
                              displayCourseCodeForTimetableEntry(
                                  entry, termCourses);
                          for (final slot in entry.slots) {
                            dayBuckets
                                .putIfAbsent(slot.day, () => <_DayCourseSlot>[])
                                .add(
                                  _DayCourseSlot(
                                    courseCode: displayCode,
                                    entry: entry,
                                    slot: slot,
                                    courseColor: color,
                                  ),
                                );
                          }
                        }

                        return Column(
                          children: [
                            header,
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: SizedBox(
                                child:
                                    AnimatedSegmentedSwitch<_TimetableViewMode>(
                                  value: _viewMode,
                                  onChanged: (value) {
                                    setState(() {
                                      _viewMode = value;
                                    });
                                  },
                                  options: const [
                                    SegmentedSwitchOption<_TimetableViewMode>(
                                      value: _TimetableViewMode.byDay,
                                      label: 'By day',
                                    ),
                                    SegmentedSwitchOption<_TimetableViewMode>(
                                      value: _TimetableViewMode.byCourse,
                                      label: 'By course',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.md,
                                right: AppSpacing.md,
                                bottom: AppSpacing.xs,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tap a schedule to edit',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.md,
                                  right: AppSpacing.md,
                                  bottom: AppSpacing.md,
                                ),
                                itemCount: _viewMode ==
                                        _TimetableViewMode.byCourse
                                    ? filtered.length + 1
                                    : _sortedDays(dayBuckets.keys).length + 1,
                                itemBuilder: (context, index) {
                                  final isLast = _viewMode ==
                                          _TimetableViewMode.byCourse
                                      ? index == filtered.length
                                      : index ==
                                          _sortedDays(dayBuckets.keys).length;
                                  if (isLast) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          top: AppSpacing.md),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _openEditor(
                                            selectedSession: selectedSession,
                                            selectedTerm: selectedTerm,
                                          ),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add schedule'),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.45),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: const StadiumBorder(),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  if (_viewMode ==
                                      _TimetableViewMode.byCourse) {
                                    final entry = filtered[index];
                                    final displayCode =
                                        displayCourseCodeForTimetableEntry(
                                      entry,
                                      termCourses,
                                    );
                                    final courseColor =
                                        displayCourseColorForTimetableEntry(
                                      entry,
                                      termCourses,
                                    );
                                    return TimetableCourseCard(
                                      courseCode: displayCode,
                                      slots: entry.slots,
                                      courseColor: courseColor,
                                      onTap: () => _openEditor(
                                        selectedSession: selectedSession,
                                        selectedTerm: selectedTerm,
                                        initial: entry,
                                      ),
                                      onDelete: () {
                                        showConfirmDeleteDialog(
                                          context,
                                          title: 'Delete schedule',
                                          message:
                                              'Delete classes for ${displayCourseCodeForTimetableEntry(entry, termCourses)}?',
                                        ).then((confirmed) async {
                                          if (!confirmed) return;
                                          await deleteTimetableEntry(entry.id);
                                        });
                                      },
                                    );
                                  }

                                  final sortedDayKeys =
                                      _sortedDays(dayBuckets.keys);
                                  final day = sortedDayKeys[index];
                                  final slots = dayBuckets[day] ??
                                      const <_DayCourseSlot>[];
                                  return _TimetableDaySection(
                                    dayLabel: day,
                                    slots: slots,
                                    onEntryTap: (entry) => _openEditor(
                                      selectedSession: selectedSession,
                                      selectedTerm: selectedTerm,
                                      initial: entry,
                                    ),
                                    onSlotDelete: (item) =>
                                        _confirmAndDeleteSingleSlot(
                                      entry: item.entry,
                                      slot: item.slot,
                                    ),
                                  );
                                },
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
        ));
  }

  Future<void> _openEditor({
    required AcademicSession selectedSession,
    required TermWindow selectedTerm,
    TimetableEntry? initial,
  }) async {
    final courses = coursesNotifier.value
        .where(
          (c) =>
              c.sessionId == selectedSession.id && c.termId == selectedTerm.id,
        )
        .map((c) => c.courseCode)
        .toSet()
        .toList()
      ..sort();

    final result = await showModalBottomSheet<_TimetableEditorResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TimetableEditorSheet(
        sessionId: selectedSession.id,
        termId: selectedTerm.id,
        courseCodes: courses,
        existingEntries: timetablesNotifier.value
            .where(
              (e) =>
                  e.sessionId == selectedSession.id &&
                  e.termId == selectedTerm.id,
            )
            .toList(growable: false),
        initial: initial,
      ),
    );

    if (result == null) return;
    final slots = result.slots
        .map(
          (s) => TimetableSlot(
            classSlotId: (s.classSlotId ?? '').trim(),
            day: s.day,
            startTime: s.startTime,
            endTime: s.endTime,
            mode: s.mode,
            classType: s.classType,
            venue: s.venue,
          ),
        )
        .toList(growable: false);

    if (initial == null) {
      await upsertTimetableByCourse(
        sessionId: selectedSession.id,
        termId: selectedTerm.id,
        courseCode: result.courseCode,
        slots: slots,
      );
    } else {
      await updateTimetableEntry(
        id: initial.id,
        sessionId: selectedSession.id,
        termId: selectedTerm.id,
        courseCode: result.courseCode,
        slots: slots,
      );
    }
  }
}

enum _TimetableViewMode {
  byDay,
  byCourse,
}

class _DayCourseSlot {
  const _DayCourseSlot({
    required this.courseCode,
    required this.entry,
    required this.slot,
    required this.courseColor,
  });

  final String courseCode;
  final TimetableEntry entry;
  final TimetableSlot slot;
  final Color courseColor;
}

String _formatSlotLocation(TimetableSlot slot) {
  if (slot.mode == 'Online') return 'Online';
  final venue = slot.venue?.trim();
  return (venue == null || venue.isEmpty) ? '-' : venue;
}

class _TimetableCardShell extends StatelessWidget {
  const _TimetableCardShell({
    required this.courseCode,
    required this.courseColor,
    required this.onTap,
    required this.onDelete,
    required this.child,
  });

  final String courseCode;
  final Color courseColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: courseColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        courseCode,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                  ],
                ),
                if (child is! SizedBox) ...[
                  const SizedBox(height: AppSpacing.sm),
                  child,
                ] else
                  child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimetableSlotMeta extends StatelessWidget {
  const _TimetableSlotMeta({
    required this.slot,
  });

  final TimetableSlot slot;

  @override
  Widget build(BuildContext context) {
    final location = _formatSlotLocation(slot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 16,
              color: Color(0xFF6043BF),
            ),
            const SizedBox(width: 8),
            Text(
              '${slot.startTime} – ${slot.endTime}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: Color(0xFF6043BF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${slot.classType.label} • $location',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimetableDaySection extends StatelessWidget {
  const _TimetableDaySection({
    required this.dayLabel,
    required this.slots,
    required this.onEntryTap,
    required this.onSlotDelete,
  });

  final String dayLabel;
  final List<_DayCourseSlot> slots;
  final ValueChanged<TimetableEntry> onEntryTap;
  final ValueChanged<_DayCourseSlot> onSlotDelete;

  int _slotStartMinutes(_DayCourseSlot item) =>
      parseTimeLabel12hToMinutes(item.slot.startTime.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final sortedSlots = [...slots]
      ..sort((a, b) => _slotStartMinutes(a).compareTo(_slotStartMinutes(b)));

    final totalClasses = sortedSlots.length;
    final classesLabel =
        totalClasses == 1 ? '1 class' : '$totalClasses classes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day + chip row
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                dayLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              LabelChip(
                label: classesLabel.toUpperCase(),
                background: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                foreground: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),

        // One card per class slot
        ...sortedSlots.map(
          (item) => _TimetableCardShell(
            courseCode: item.courseCode,
            courseColor: item.courseColor,
            onTap: () => onEntryTap(item.entry),
            onDelete: () => onSlotDelete(item),
            child: _TimetableSlotMeta(slot: item.slot),
          ),
        ),
      ],
    );
  }
}

class _TimetableEditorResult {
  const _TimetableEditorResult({
    required this.courseCode,
    required this.slots,
  });

  final String courseCode;
  final List<ClassSlotDraft> slots;
}

class _TimetableEditorSheet extends StatefulWidget {
  const _TimetableEditorSheet({
    required this.sessionId,
    required this.termId,
    required this.courseCodes,
    required this.existingEntries,
    this.initial,
  });

  final String sessionId;
  final String termId;
  final List<String> courseCodes;
  final List<TimetableEntry> existingEntries;
  final TimetableEntry? initial;

  @override
  State<_TimetableEditorSheet> createState() => _TimetableEditorSheetState();
}

class _TimetableEditorSheetState extends State<_TimetableEditorSheet> {
  String? _selectedCourseCode;
  late List<String> _courseCodes;
  late Map<String, List<ClassSlotDraft>> _slotsByCourse;
  late List<ClassSlotDraft> _slots;

  @override
  void initState() {
    super.initState();
    _courseCodes = [...widget.courseCodes]..sort();
    _slotsByCourse = {
      for (final entry in widget.existingEntries)
        entry.courseCode: entry.slots
            .map(
              (s) => ClassSlotDraft(
                classSlotId: s.classSlotId,
                day: s.day,
                startTime: s.startTime,
                endTime: s.endTime,
                mode: s.mode,
                classType: s.classType,
                venue: s.venue,
              ),
            )
            .toList(growable: false),
    };
    _selectedCourseCode = widget.initial?.courseCode;
    _selectedCourseCode ??= _courseCodes.isNotEmpty ? _courseCodes.first : null;
    if (widget.initial != null) {
      final current = _selectedCourseCode!;
      _slotsByCourse[current] ??= widget.initial!.slots
          .map(
            (s) => ClassSlotDraft(
              classSlotId: s.classSlotId,
              day: s.day,
              startTime: s.startTime,
              endTime: s.endTime,
              mode: s.mode,
              classType: s.classType,
              venue: s.venue,
            ),
          )
          .toList(growable: false);
    }
    _slots = _cloneSlots(_slotsByCourse[_selectedCourseCode] ?? const []);
  }

  List<ClassSlotDraft> _cloneSlots(List<ClassSlotDraft> slots) {
    return slots
        .map(
          (s) => ClassSlotDraft(
            classSlotId: s.classSlotId,
            day: s.day,
            startTime: s.startTime,
            endTime: s.endTime,
            mode: s.mode,
            classType: s.classType,
            venue: s.venue,
          ),
        )
        .toList(growable: true);
  }

  Future<void> _addSlot() async {
    final slot = await ClassSlotEditorScreen.show(context);
    if (slot == null) return;
    setState(() {
      _slots.add(slot);
      if (_selectedCourseCode != null) {
        _slotsByCourse[_selectedCourseCode!] = _cloneSlots(_slots);
      }
    });
  }

  Future<void> _editSlot(ClassSlotDraft slot) async {
    final updated = await ClassSlotEditorScreen.show(context, initial: slot);
    if (updated == null) return;
    setState(() {
      final index = _slots.indexOf(slot);
      if (index != -1) _slots[index] = updated;
      if (_selectedCourseCode != null) {
        _slotsByCourse[_selectedCourseCode!] = _cloneSlots(_slots);
      }
    });
  }

  Future<String?> _addCourseRequested() async {
    final newCode = await CourseDialog.show(
      context,
      sessionId: widget.sessionId,
      termId: widget.termId,
    );
    if (newCode == null) return null;

    setState(() {
      if (!_courseCodes.contains(newCode)) {
        _courseCodes.add(newCode);
        _courseCodes.sort();
      }
      _slotsByCourse.putIfAbsent(newCode, () => []);
    });
    return newCode;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final canSave = _selectedCourseCode != null && _slots.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Edit Schedule' : 'Add Schedule',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ClassForm(
              courseCodes: _courseCodes,
              selectedCourseCode: _selectedCourseCode,
              slots: _slots,
              slotsByCourse: _slotsByCourse,
              onCourseChanged: (value) {
                if (value == null) return;
                setState(() {
                  if (_selectedCourseCode != null) {
                    _slotsByCourse[_selectedCourseCode!] = _cloneSlots(_slots);
                  }
                  _selectedCourseCode = value;
                  _slots = _cloneSlots(_slotsByCourse[value] ?? const []);
                });
              },
              onSlotsHydratedForCourse: (_) {},
              onAddSlot: _addSlot,
              onEditSlot: _editSlot,
              onRemoveSlot: (slot) {
                setState(() {
                  _slots.remove(slot);
                  if (_selectedCourseCode != null) {
                    _slotsByCourse[_selectedCourseCode!] = _cloneSlots(_slots);
                  }
                });
              },
              onAddCourseRequested: _addCourseRequested,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: isEdit
                  ? ElevatedButton(
                      onPressed: canSave
                          ? () {
                              Navigator.pop(
                                context,
                                _TimetableEditorResult(
                                  courseCode: _selectedCourseCode!,
                                  slots: _slots,
                                ),
                              );
                            }
                          : null,
                      child: const Text('Save schedule'),
                    )
                  : ElevatedButton.icon(
                      onPressed: canSave
                          ? () {
                              Navigator.pop(
                                context,
                                _TimetableEditorResult(
                                  courseCode: _selectedCourseCode!,
                                  slots: _slots,
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add schedule'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
