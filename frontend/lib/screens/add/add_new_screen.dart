import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/mock/mock_tasks.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/task.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/course_store.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/common/form_fields.dart';
import '../../core/widgets/schedule/class_slot_sheet.dart';
import '../../core/widgets/add/task_form.dart';
import '../../core/widgets/add/class_form.dart';
import '../../core/widgets/add/event_form.dart';
import '../../core/widgets/add/add_course_dialog.dart';

enum AddType { task, classSlot, event }

class AddNewScreen extends StatefulWidget {
  const AddNewScreen({super.key, this.initialType});

  final AddType? initialType;

  @override
  State<AddNewScreen> createState() => _AddNewScreenState();
}

class _AddNewScreenState extends State<AddNewScreen> {
  late AddType _selectedType;
  String? _selectedSessionId;
  String? _selectedTermId;

  final _taskTitleController = TextEditingController();
  final _taskNoteController = TextEditingController();
  DateTime _taskDueDateTime = DateTime.now().add(const Duration(days: 1));
  String? _taskCourseCode;

  String? _classCourseCode;
  final List<ClassSlotDraft> _classSlots = [];

  final _eventNameController = TextEditingController();
  DateTime _eventStartDate = DateTime.now();
  DateTime? _eventEndDate;
  TimeOfDay? _eventStartTime;
  TimeOfDay? _eventEndTime;
  bool _eventAllDay = true;
  bool _hideClassesInEvent = true;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? AddType.task;
    final now = DateTime.now();
    _eventStartDate = now;
    _eventEndDate = now;
    _eventStartTime = const TimeOfDay(hour: 9, minute: 0);
    _eventEndTime = const TimeOfDay(hour: 11, minute: 0);
    final active = currentAcademicSessionNotifier.value;
    if (active != null) {
      _selectedSessionId = active.id;
      final windows = buildTermWindows(active);
      _selectedTermId = defaultTermId(windows);
    }
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskNoteController.dispose();
    _eventNameController.dispose();
    super.dispose();
  }

  bool _areEventTimesValid() {
    if (_eventStartTime == null || _eventEndTime == null) return true;

    final isSameDay = _eventEndDate == null ||
        (_eventEndDate!.year == _eventStartDate.year &&
            _eventEndDate!.month == _eventStartDate.month &&
            _eventEndDate!.day == _eventStartDate.day);

    if (!isSameDay) return true;

    final startMinutes = _eventStartTime!.hour * 60 + _eventStartTime!.minute;
    final endMinutes = _eventEndTime!.hour * 60 + _eventEndTime!.minute;
    return endMinutes >= startMinutes;
  }

  Future<void> _pickTaskDate(TermWindow term) async {
    final initialDate = clampToTerm(_taskDueDateTime, term);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: term.start,
      lastDate: term.end,
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _taskDueDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _taskDueDateTime.hour,
        _taskDueDateTime.minute,
      );
    });
  }

  Future<void> _pickTaskTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_taskDueDateTime),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _taskDueDateTime = DateTime(
        _taskDueDateTime.year,
        _taskDueDateTime.month,
        _taskDueDateTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _pickEventStartDate(
    TermWindow term,
  ) async {
    final initialDate = clampToTerm(_eventStartDate, term);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: term.start,
      lastDate: term.end,
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _eventStartDate = picked;
      if (_eventEndDate != null && _eventEndDate!.isBefore(_eventStartDate)) {
        _eventEndDate = null;
      }
    });
  }

  Future<void> _pickEventEndDate(TermWindow term) async {
    final defaultEnd = _eventEndDate ?? _eventStartDate;
    final safeInitial = clampToTerm(defaultEnd, term);
    final safeFirstDate = _eventStartDate.isBefore(term.start)
        ? term.start
        : _eventStartDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial.isBefore(safeFirstDate)
          ? safeFirstDate
          : safeInitial,
      firstDate: safeFirstDate,
      lastDate: term.end,
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _eventEndDate = picked);
  }

  Future<void> _pickEventStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventStartTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _eventStartTime = picked);
  }

  Future<void> _pickEventEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventEndTime ?? (_eventStartTime ?? TimeOfDay.now()),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _eventEndTime = picked);
  }

  Future<void> _addClassSlot() async {
    final slot = await AddClassSlotSheet.show(context);
    if (slot == null) return;
    setState(() => _classSlots.add(slot));
  }
  Future<String?> _showAddCourseDialogForTask(
    String sessionId,
    String termId,
  ) async {
    final newCode = await AddCourseDialog.show(
      context,
      sessionId: sessionId,
      termId: termId,
    );
    if (newCode == null) return null;
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$newCode added successfully!')),
    );
    return newCode;
  }

  Future<String?> _showAddCourseDialogForClass(
    String sessionId,
    String termId,
  ) async {
    final newCode = await AddCourseDialog.show(
      context,
      sessionId: sessionId,
      termId: termId,
    );
    if (newCode == null) return null;
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$newCode added successfully!')),
    );
    return newCode;
  }

  Future<void> _editClassSlot(ClassSlotDraft slot) async {
    final updated = await AddClassSlotSheet.show(
      context,
      initial: slot,
    );
    if (updated == null) return;

    setState(() {
      final index = _classSlots.indexOf(slot);
      if (index != -1) {
        _classSlots[index] = updated;
      }
    });
  }

  void _saveTask({
    required String sessionId,
    required List<String> courseCodes,
  }) {
    final title = _taskTitleController.text.trim();
    if (title.isEmpty || _taskCourseCode == null) return;

    final matched = coursesNotifier.value.where((c) {
      return c.sessionId == sessionId && c.courseCode == _taskCourseCode;
    }).toList();
    final colorHex = matched.isEmpty ? '#6C4DD9' : matched.first.courseColor;
    final colorValue = int.tryParse(colorHex.replaceFirst('#', '0xFF'));

    final newTask = Task(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      courseCode: _taskCourseCode!,
      courseColor: Color(colorValue ?? 0xFF6C4DD9),
      title: title,
      description: _taskNoteController.text.trim().isEmpty
          ? null
          : _taskNoteController.text.trim(),
      dueDateTime: _taskDueDateTime,
      status: TaskStatus.ongoing,
    );
    mockTasksNotifier.value = [...mockTasksNotifier.value, newTask];
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task added.')),
    );
  }

  Future<void> _saveClass({
    required String sessionId,
    required String termId,
  }) async {
    if (_classCourseCode == null || _classSlots.isEmpty) return;

    await upsertTimetableByCourse(
      sessionId: sessionId,
      termId: termId,
      courseCode: _classCourseCode!,
      slots: _classSlots
          .map(
            (slot) => TimetableSlot(
              day: slot.day,
              startTime: slot.startTime,
              endTime: slot.endTime,
              mode: slot.mode,
              classType: slot.classType,
              venue: slot.venue,
            ),
          )
          .toList(growable: false),
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timetable saved.')),
    );
  }

  void _saveEvent() {
    if (_eventNameController.text.trim().isEmpty) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event added (mock).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = currentAcademicSessionNotifier.value;

    if (activeSession == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add New')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EmptyStateCard(
              title: 'No Session Yet',
              subtitle:
                  'Set up your academic session first before adding task, class, or event.',
              buttonText: 'Set up session',
              onPressed: () {
                AcademicSessionSetupBottomSheet.show(context);
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New'),
      ),
      body: ValueListenableBuilder(
        valueListenable: coursesNotifier,
        builder: (context, courses, _) {
          // activeSession is guaranteed to be non-null here due to early return above
          final session = activeSession;
          return ValueListenableBuilder<List<AcademicSession>>(
            valueListenable: academicSessionsNotifier,
            builder: (context, sessionsList, _) {
              final sessions = [...sessionsList];
              if (!sessions.any((s) => s.id == session.id)) {
                sessions.add(session);
              }

              final selectedSession = sessions.firstWhere(
                (s) => s.id == (_selectedSessionId ?? session.id),
                orElse: () => session,
              );
              final termWindows = buildTermWindows(selectedSession);
              final selectedTerm = termWindows.firstWhere(
                (term) =>
                    term.id ==
                    ((_selectedTermId != null &&
                            termWindows.any((t) => t.id == _selectedTermId))
                        ? _selectedTermId
                        : defaultTermId(termWindows)),
                orElse: () => termWindows.first,
              );

              // Filter courses by session and term
              final sessionAndTermCourses = courses
                  .where((c) => c.sessionId == selectedSession.id && c.termId == selectedTerm.id)
                  .toList(growable: false);
              final persistedClassSlotsByCourse = {
                for (final entry in timetablesNotifier.value.where(
                  (e) =>
                      e.sessionId == selectedSession.id &&
                      e.termId == selectedTerm.id,
                ))
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
              
              final courseCodes = sessionAndTermCourses.map((c) => c.courseCode).toSet().toList()
                ..sort();

              final canSaveTask =
                  _taskTitleController.text.trim().isNotEmpty &&
                  _taskCourseCode != null &&
                  isInTerm(_taskDueDateTime, selectedTerm);
              final canSaveClass = _classCourseCode != null && _classSlots.isNotEmpty;
              final eventDatesValid = isInTerm(_eventStartDate, selectedTerm) &&
                  _eventEndDate != null &&
                  isInTerm(_eventEndDate!, selectedTerm) &&
                  !_eventEndDate!.isBefore(_eventStartDate);

              final eventTimesValid = _eventAllDay
                  ? true
                  : (_eventStartTime != null &&
                      _eventEndTime != null &&
                      _areEventTimesValid());

              final canSaveEvent = _eventNameController.text.trim().isNotEmpty &&
                  eventDatesValid &&
                  eventTimesValid;

              Widget typeSpecificForm;
              if (_selectedType == AddType.task) {
                typeSpecificForm = TaskForm(
                  titleController: _taskTitleController,
                  noteController: _taskNoteController,
                  dueDateTime: _taskDueDateTime,
                  selectedTerm: selectedTerm,
                  courseCodes: courseCodes,
                  selectedCourseCode: _taskCourseCode,
                  onTitleChanged: (value) => setState(() {}),
                  onCourseChanged: (value) =>
                      setState(() => _taskCourseCode = value),
                  onPickDate: () => _pickTaskDate(selectedTerm),
                  onPickTime: _pickTaskTime,
                  onAddCourseRequested: () =>
                      _showAddCourseDialogForTask(selectedSession.id, selectedTerm.id),
                );
              } else if (_selectedType == AddType.classSlot) {
                typeSpecificForm = ClassForm(
                  courseCodes: courseCodes,
                  selectedCourseCode: _classCourseCode,
                  slots: _classSlots,
                  slotsByCourse: persistedClassSlotsByCourse,
                  onCourseChanged: (value) =>
                      setState(() => _classCourseCode = value),
                  onSlotsHydratedForCourse: (hydratedSlots) {
                    setState(() {
                      _classSlots
                        ..clear()
                        ..addAll(hydratedSlots);
                    });
                  },
                  onAddSlot: _addClassSlot,
                  onEditSlot: _editClassSlot,
                  onRemoveSlot: (slot) =>
                      setState(() => _classSlots.remove(slot)),
                  onAddCourseRequested: () =>
                      _showAddCourseDialogForClass(selectedSession.id, selectedTerm.id),
                );
              } else {
                typeSpecificForm = EventForm(
                  eventNameController: _eventNameController,
                  allDay: _eventAllDay,
                  startDate: _eventStartDate,
                  endDate: _eventEndDate,
                  startTime: _eventStartTime,
                  endTime: _eventEndTime,
                  hideClassesInEvent: _hideClassesInEvent,
                  selectedTerm: selectedTerm,
                  datesValid: eventDatesValid,
                  timesValid: eventTimesValid,
                  onAllDayChanged: (value) {
                    setState(() {
                      _eventAllDay = value;
                      if (_eventAllDay) {
                        _eventStartTime = null;
                        _eventEndTime = null;
                      } else {
                        _eventStartTime ??= const TimeOfDay(hour: 9, minute: 0);
                        _eventEndTime ??= const TimeOfDay(hour: 11, minute: 0);
                      }
                    });
                  },
                  onNameChanged: (value) => setState(() {}),
                  onPickStartDate: () => _pickEventStartDate(selectedTerm),
                  onPickEndDate: () => _pickEventEndDate(selectedTerm),
                  onPickStartTime: _pickEventStartTime,
                  onPickEndTime: _pickEventEndTime,
                  onHideClassesChanged: (value) {
                    setState(() => _hideClassesInEvent = value);
                  },
                );
              }

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _TypeTabs(
                      selected: _selectedType,
                      onChanged: (value) => setState(() => _selectedType = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownField<String>(
                              label: 'Academic Session',
                              value: selectedSession.id,
                              items: sessions
                                  .map(
                                    (s) => DropdownMenuEntry<String>(
                                      value: s.id,
                                      label: s.name,
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                final nextSession = sessions.firstWhere(
                                  (s) => s.id == value,
                                  orElse: () => session,
                                );
                                final nextTerms = buildTermWindows(nextSession);
                                setState(() {
                                  _selectedSessionId = value;
                                  _selectedTermId = defaultTermId(nextTerms);
                                  _taskCourseCode = null;
                                  _classCourseCode = null;
                                  _classSlots.clear();
                                });
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownField<String>(
                              label: 'Academic Term',
                              value: selectedTerm.id,
                              items: termWindows
                                  .map(
                                    (term) => DropdownMenuEntry<String>(
                                      value: term.id,
                                      label: term.label,
                                      
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedTermId = value;
                                  _taskCourseCode = null;
                                  _classCourseCode = null;
                                  _classSlots.clear();
                                });
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            typeSpecificForm,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedType == AddType.task
                            ? (canSaveTask
                                ? () => _saveTask(
                                      sessionId: selectedSession.id,
                                      courseCodes: courseCodes,
                                    )
                                : null)
                            : _selectedType == AddType.classSlot
                                ? (canSaveClass
                                    ? () => _saveClass(
                                          sessionId: selectedSession.id,
                                          termId: selectedTerm.id,
                                        )
                                    : null)
                                : (canSaveEvent ? _saveEvent : null),
                        child: Text(
                          _selectedType == AddType.task
                              ? 'Add task'
                              : _selectedType == AddType.classSlot
                                  ? 'Add class'
                                  : 'Add event',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.selected,
    required this.onChanged,
  });

  final AddType selected;
  final ValueChanged<AddType> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    Widget tab(String label, AddType value) {
      final isSelected = selected == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected ? Colors.white : primary,
                  ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          tab('Task', AddType.task),
          tab('Class', AddType.classSlot),
          tab('Event', AddType.event),
        ],
      ),
    );
  }
}


