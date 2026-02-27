import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/mock/mock_academic_session.dart';
import '../../core/mock/mock_courses.dart';
import '../../core/mock/mock_tasks.dart';
import '../../core/models/task.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/common/form_fields.dart';
import '../../core/widgets/schedule/class_slot_sheet.dart';
import '../../core/widgets/add/task_form.dart';
import '../../core/widgets/add/class_form.dart';
import '../../core/widgets/add/event_form.dart';

enum _AddType { task, classSlot, event }

class AddNewScreen extends StatefulWidget {
  const AddNewScreen({super.key});

  @override
  State<AddNewScreen> createState() => _AddNewScreenState();
}

class _AddNewScreenState extends State<AddNewScreen> {
  _AddType _selectedType = _AddType.task;
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

    final matched = mockCoursesNotifier.value.where((c) {
      return c.sessionId == sessionId && c.courseCode == _taskCourseCode;
    }).toList();
    final colorHex = matched.isEmpty ? '#6C4DD9' : matched.first.courseColor;
    final colorValue = int.tryParse(colorHex.replaceFirst('#', '0xFF'));

    mockTasks.add(
      Task(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        courseCode: _taskCourseCode!,
        courseColor: Color(colorValue ?? 0xFF6C4DD9),
        title: title,
        description: _taskNoteController.text.trim().isEmpty
            ? null
            : _taskNoteController.text.trim(),
        dueDateTime: _taskDueDateTime,
        status: TaskStatus.ongoing,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task added.')),
    );
  }

  void _saveClass() {
    if (_classCourseCode == null || _classSlots.isEmpty) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class added (mock).')),
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
        body: EmptyStateCard(
          title: 'No Session Yet',
          subtitle:
              'Set up your academic session first before adding task, class, or event.',
          buttonText: 'Set up session',
          onPressed: () {
            AcademicSessionSetupBottomSheet.show(context);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New'),
      ),
      body: ValueListenableBuilder(
        valueListenable: mockCoursesNotifier,
        builder: (context, courses, _) {
          final menuItemStyle = ButtonStyle(
            textStyle: WidgetStateProperty.all<TextStyle?>(
              Theme.of(context).textTheme.bodyLarge,
            ),
          );
          final sessions = [...mockAcademicSessions];
          if (!sessions.any((s) => s.id == activeSession.id)) {
            sessions.add(activeSession);
          }

          final selectedSession = sessions.firstWhere(
            (s) => s.id == (_selectedSessionId ?? activeSession.id),
            orElse: () => activeSession,
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

          final sessionCourses = courses
              .where((c) => c.sessionId == selectedSession.id)
              .toList(growable: false);
          final courseCodes = sessionCourses.map((c) => c.courseCode).toSet().toList()
            ..sort();

          if (_taskCourseCode != null && !courseCodes.contains(_taskCourseCode)) {
            _taskCourseCode = null;
          }
          if (_classCourseCode != null && !courseCodes.contains(_classCourseCode)) {
            _classCourseCode = null;
          }

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
          if (_selectedType == _AddType.task) {
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
            );
          } else if (_selectedType == _AddType.classSlot) {
            typeSpecificForm = ClassForm(
              courseCodes: courseCodes,
              selectedCourseCode: _classCourseCode,
              slots: _classSlots,
              onCourseChanged: (value) =>
                  setState(() => _classCourseCode = value),
              onAddSlot: _addClassSlot,
              onEditSlot: _editClassSlot,
              onRemoveSlot: (slot) =>
                  setState(() => _classSlots.remove(slot)),
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
                              orElse: () => activeSession,
                            );
                            final nextTerms = buildTermWindows(nextSession);
                            setState(() {
                              _selectedSessionId = value;
                              _selectedTermId = defaultTermId(nextTerms);
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownField<String>(
                          label: 'Academic Term',
                          value: selectedTerm.id,
                          items: termWindows
                              .map(
                                (term) => DropdownMenuEntry<String>(
                                  value: term.id,
                                  label: term.label,
                                  style: menuItemStyle,
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedTermId = value);
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
                    onPressed: _selectedType == _AddType.task
                        ? (canSaveTask
                            ? () => _saveTask(
                                  sessionId: selectedSession.id,
                                  courseCodes: courseCodes,
                                )
                            : null)
                        : _selectedType == _AddType.classSlot
                            ? (canSaveClass ? _saveClass : null)
                            : (canSaveEvent ? _saveEvent : null),
                    child: Text(
                      _selectedType == _AddType.task
                          ? 'Add task'
                          : _selectedType == _AddType.classSlot
                              ? 'Add class'
                              : 'Add event',
                    ),
                  ),
                ),
              ],
            ),
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

  final _AddType selected;
  final ValueChanged<_AddType> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    Widget tab(String label, _AddType value) {
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
          tab('Task', _AddType.task),
          tab('Class', _AddType.classSlot),
          tab('Event', _AddType.event),
        ],
      ),
    );
  }
}

