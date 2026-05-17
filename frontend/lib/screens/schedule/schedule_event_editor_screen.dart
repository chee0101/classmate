import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/academic_event.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/add/event_form.dart';

class ScheduleEventEditorScreen extends StatefulWidget {
  const ScheduleEventEditorScreen({
    super.key,
    required this.initialEvent,
    required this.selectedTerm,
  });

  final AcademicEvent initialEvent;
  final TermWindow selectedTerm;

  static Future<AcademicEvent?> show(
    BuildContext context, {
    required AcademicEvent initialEvent,
    required TermWindow selectedTerm,
  }) {
    return Navigator.of(context).push<AcademicEvent>(
      MaterialPageRoute(
        builder: (_) => ScheduleEventEditorScreen(
          initialEvent: initialEvent,
          selectedTerm: selectedTerm,
        ),
      ),
    );
  }

  @override
  State<ScheduleEventEditorScreen> createState() => _ScheduleEventEditorScreenState();
}

class _ScheduleEventEditorScreenState extends State<ScheduleEventEditorScreen> {
  final _eventNameController = TextEditingController();
  final _eventLocationController = TextEditingController();
  late DateTime _eventStartDate;
  DateTime? _eventEndDate;
  TimeOfDay? _eventStartTime;
  TimeOfDay? _eventEndTime;
  late bool _eventAllDay;
  late bool _hideClassesInEvent;

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 0, 0);
  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59);

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    _eventNameController.text = event.title;
    _eventLocationController.text = event.location ?? '';
    _eventAllDay = event.allDay;
    _hideClassesInEvent = event.hideClassesDuringEvent;
    _eventStartDate = _startOfDay(event.startDateTime);
    _eventEndDate = _endOfDay(event.endDateTime);
    if (!_eventAllDay) {
      _eventStartTime = TimeOfDay.fromDateTime(event.startDateTime);
      _eventEndTime = TimeOfDay.fromDateTime(event.endDateTime);
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventLocationController.dispose();
    super.dispose();
  }

  bool _areEventTimesValid() {
    if (_eventStartTime == null || _eventEndTime == null) return true;
    final endDate = _eventEndDate ?? _eventStartDate;
    final sameDay = endDate.year == _eventStartDate.year &&
        endDate.month == _eventStartDate.month &&
        endDate.day == _eventStartDate.day;
    if (!sameDay) return true;
    final startMinutes = _eventStartTime!.hour * 60 + _eventStartTime!.minute;
    final endMinutes = _eventEndTime!.hour * 60 + _eventEndTime!.minute;
    return endMinutes > startMinutes;
  }

  bool get _datesValid {
    final term = widget.selectedTerm;
    final endDate = _eventEndDate;
    if (endDate == null) return false;
    final startInRange = !(_eventStartDate.isBefore(term.start) ||
        _eventStartDate.isAfter(term.end));
    final endInRange = !(endDate.isBefore(term.start) || endDate.isAfter(term.end));
    return startInRange && endInRange && !endDate.isBefore(_eventStartDate);
  }

  Future<void> _pickStartDate() async {
    final term = widget.selectedTerm;
    
    // 1. Clamp initial date to strictly fall within term start and end
    DateTime safeInitial = _eventStartDate;
    if (safeInitial.isBefore(term.start)) safeInitial = term.start;
    if (safeInitial.isAfter(term.end)) safeInitial = term.end;

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: term.start,
      lastDate: term.end,
    );
    
    if (picked == null) return;
    
    setState(() {
      _eventStartDate = _startOfDay(picked);
      if (_eventEndDate != null && _eventEndDate!.isBefore(_eventStartDate)) {
        _eventEndDate = _endOfDay(_eventStartDate);
      }
    });
  }

  Future<void> _pickEndDate() async {
    final term = widget.selectedTerm;
    
    // 1. Calculate a safe firstDate: must be >= term.start and <= term.end
    DateTime safeFirst = _eventStartDate;
    if (safeFirst.isBefore(term.start)) safeFirst = term.start;
    if (safeFirst.isAfter(term.end)) safeFirst = term.end;

    // 2. Calculate a safe initialDate: must be >= safeFirst and <= term.end
    DateTime safeInitial = _eventEndDate ?? safeFirst;
    if (safeInitial.isBefore(safeFirst)) safeInitial = safeFirst;
    if (safeInitial.isAfter(term.end)) safeInitial = term.end;

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: safeFirst,
      lastDate: term.end,
    );
    
    if (picked == null) return;
    
    setState(() => _eventEndDate = _endOfDay(picked));
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventStartTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    setState(() => _eventStartTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventEndTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked == null) return;
    setState(() => _eventEndTime = picked);
  }

  void _save() {
    final title = _eventNameController.text.trim();
    if (title.isEmpty || !_datesValid || (!_eventAllDay && !_areEventTimesValid())) {
      return;
    }
    final endDate = _eventEndDate ?? _eventStartDate;
    late final DateTime startDateTime;
    late final DateTime endDateTime;
    if (_eventAllDay) {
      startDateTime = _startOfDay(_eventStartDate);
      endDateTime = _endOfDay(endDate);
    } else {
      if (_eventStartTime == null || _eventEndTime == null) return;
      startDateTime = DateTime(
        _eventStartDate.year,
        _eventStartDate.month,
        _eventStartDate.day,
        _eventStartTime!.hour,
        _eventStartTime!.minute,
      );
      endDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        _eventEndTime!.hour,
        _eventEndTime!.minute,
      );
      if (!endDateTime.isAfter(startDateTime)) return;
    }
    Navigator.of(context).pop(
      widget.initialEvent.copyWith(
        title: title,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        allDay: _eventAllDay,
        hideClassesDuringEvent: _hideClassesInEvent,
        location: _eventLocationController.text.trim().isEmpty
            ? null
            : _eventLocationController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _eventNameController.text.trim().isNotEmpty &&
        _datesValid &&
        (_eventAllDay || _areEventTimesValid());
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Event')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: EventForm(
                  eventNameController: _eventNameController,
                  locationController: _eventLocationController,
                  allDay: _eventAllDay,
                  startDate: _eventStartDate,
                  endDate: _eventEndDate,
                  startTime: _eventStartTime,
                  endTime: _eventEndTime,
                  hideClassesInEvent: _hideClassesInEvent,
                  selectedTerm: widget.selectedTerm,
                  datesValid: _datesValid,
                  timesValid: _areEventTimesValid(),
                  onAllDayChanged: (value) {
                    setState(() {
                      _eventAllDay = value;
                      if (_eventAllDay) {
                        _eventStartTime = null;
                        _eventEndTime = null;
                      } else {
                        _eventStartTime ??= const TimeOfDay(hour: 9, minute: 0);
                        _eventEndTime ??= const TimeOfDay(hour: 10, minute: 0);
                      }
                    });
                  },
                  onNameChanged: (_) => setState(() {}),
                  onLocationChanged: (_) => setState(() {}),
                  onPickStartDate: _pickStartDate,
                  onPickEndDate: _pickEndDate,
                  onPickStartTime: _pickStartTime,
                  onPickEndTime: _pickEndTime,
                  onHideClassesChanged: (value) =>
                      setState(() => _hideClassesInEvent = value),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSave ? _save : null,
                child: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
