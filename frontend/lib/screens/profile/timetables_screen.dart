import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/mock/mock_academic_session.dart';
import '../../core/mock/mock_courses.dart';
import '../../core/mock/mock_timetables.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/class_type.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/add/add_course_dialog.dart';
import '../../core/widgets/add/class_form.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';
import '../../core/widgets/schedule/class_slot_sheet.dart';
import 'class_slot_editor_screen.dart';

class TimetablesScreen extends StatefulWidget {
  const TimetablesScreen({super.key});

  @override
  State<TimetablesScreen> createState() => _TimetablesScreenState();
}

class _TimetablesScreenState extends State<TimetablesScreen> {
  String? _selectedSessionId;
  String? _selectedTermId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<List<AcademicSession>>(
        valueListenable: mockAcademicSessionsNotifier,
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
                  title: 'No academic session',
                  subtitle:
                      'Set up an academic session first to manage timetable slots',
                  buttonText: 'Add session',
                  icon: Icons.calendar_today_outlined,
                  onPressed: () {
                    AcademicSessionSetupBottomSheet.show(context);
                  },
                ),
              ),
            );
          }

          final refs = <({AcademicSession session, TermWindow term})>[];
          for (final session in sessions) {
            for (final term in buildTermWindows(session)) {
              refs.add((session: session, term: term));
            }
          }

          final now = DateTime.now();
          var selectedRef = refs.first;
          final current = refs.where(
            (ref) =>
                !now.isBefore(ref.term.start) && !now.isAfter(ref.term.end),
          );
          if (current.isNotEmpty) selectedRef = current.first;

          final selectedSessionId =
              _selectedSessionId ?? selectedRef.session.id;
          final selectedTermId = _selectedTermId ?? selectedRef.term.id;
          final exact = refs.where(
            (ref) =>
                ref.session.id == selectedSessionId &&
                ref.term.id == selectedTermId,
          );
          if (exact.isNotEmpty) selectedRef = exact.first;

          final selectedSession = selectedRef.session;
          final selectedTerm = selectedRef.term;

          return ValueListenableBuilder<List<TimetableEntry>>(
            valueListenable: mockTimetablesNotifier,
            builder: (context, entries, _) {
              final filtered = entries
                  .where(
                    (e) =>
                        e.sessionId == selectedSession.id &&
                        e.termId == selectedTerm.id,
                  )
                  .toList(growable: false);

              final header = Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.lg,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.sm,
                ),
                child: SessionHeader(
                  sessions: sessions,
                  selectedSessionId: selectedSession.id,
                  selectedTermId: selectedTerm.id,
                  onSelectionChanged: (sessionId, termId) {
                    setState(() {
                      _selectedSessionId = sessionId;
                      _selectedTermId = termId;
                    });
                  },
                ),
              );

              if (filtered.isEmpty) {
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
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: EmptyStateCard(
                          title: 'No timetable in ${selectedTerm.label}',
                          subtitle:
                              'Add class slots for courses in ${selectedSession.name}.',
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

              return Column(
                children: [
                  header,
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        bottom: AppSpacing.lg,
                      ),
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openEditor(
                                  selectedSession: selectedSession,
                                  selectedTerm: selectedTerm,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add timetable'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.45),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                          );
                        }

                        final entry = filtered[index];
                        return _TimetableCard(
                          entry: entry,
                          onTap: () => _openEditor(
                            selectedSession: selectedSession,
                            selectedTerm: selectedTerm,
                            initial: entry,
                          ),
                          onDelete: () {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: const Text('Delete timetable'),
                                content: Text(
                                  'Delete timetable for ${entry.courseCode}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      deleteTimetableEntry(entry.id);
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor({
    required AcademicSession selectedSession,
    required TermWindow selectedTerm,
    TimetableEntry? initial,
  }) async {
    final courses = mockCoursesNotifier.value
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
        existingEntries: mockTimetablesNotifier.value
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
      upsertTimetableByCourse(
        sessionId: selectedSession.id,
        termId: selectedTerm.id,
        courseCode: result.courseCode,
        slots: slots,
      );
    } else {
      updateTimetableEntry(
        id: initial.id,
        sessionId: selectedSession.id,
        termId: selectedTerm.id,
        courseCode: result.courseCode,
        slots: slots,
      );
    }
  }
}

class _TimetableCard extends StatelessWidget {
  const _TimetableCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final TimetableEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static const List<String> _dayOrder = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  int _slotStartMinutes(TimetableSlot slot) {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
            .firstMatch(slot.startTime.trim());
    if (match == null) return 0;
    final hour12 = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final period = (match.group(3) ?? 'AM').toUpperCase();
    final hour24 = period == 'AM' ? hour12 % 12 : (hour12 % 12) + 12;
    return (hour24 * 60) + minute;
  }

  String _locationLabel(TimetableSlot slot) {
    if (slot.mode == 'Online') return 'Online';
    final venue = slot.venue?.trim();
    return (venue == null || venue.isEmpty) ? '-' : venue;
  }

  Map<String, List<TimetableSlot>> _groupSlotsByDay(List<TimetableSlot> slots) {
    final grouped = <String, List<TimetableSlot>>{};
    for (final slot in slots) {
      grouped.putIfAbsent(slot.day, () => <TimetableSlot>[]).add(slot);
    }
    for (final day in grouped.keys) {
      grouped[day]!.sort(
        (a, b) => _slotStartMinutes(a).compareTo(_slotStartMinutes(b)),
      );
    }
    return grouped;
  }

  List<String> _sortedDays(Iterable<String> days) {
    final sorted = days.toList(growable: false);
    sorted.sort((a, b) {
      final ai = _dayOrder.indexOf(a);
      final bi = _dayOrder.indexOf(b);
      if (ai == -1 && bi == -1) return a.compareTo(b);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
          splashColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          highlightColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.courseCode,
                        style: Theme.of(context).textTheme.titleLarge,
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
                ...() {
                  final grouped = _groupSlotsByDay(entry.slots);
                  final days = _sortedDays(grouped.keys);
                  return days.map((day) {
                    final slots = grouped[day] ?? const <TimetableSlot>[];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day.length >= 3 ? day.substring(0, 3) : day,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          ...slots.map(
                            (slot) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 160,
                                    child: Text(
                                      '${slot.startTime} - ${slot.endTime}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color:
                                                Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${slot.classType.label} · ${_locationLabel(slot)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color:
                                                Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(growable: false);
                }(),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _addCourseRequested() async {
    final newCode = await AddCourseDialog.show(
      context,
      sessionId: widget.sessionId,
      termId: widget.termId,
    );
    if (newCode == null) return;

    setState(() {
      if (!_courseCodes.contains(newCode)) {
        _courseCodes.add(newCode);
        _courseCodes.sort();
      }
      _slotsByCourse.putIfAbsent(newCode, () => []);
      _selectedCourseCode = newCode;
      _slots = _cloneSlots(_slotsByCourse[newCode] ?? const []);
    });
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
