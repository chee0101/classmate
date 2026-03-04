import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/widgets/common/form_fields.dart';
import '../../core/widgets/schedule/class_slot_sheet.dart';

class ClassSlotEditorScreen extends StatefulWidget {
  const ClassSlotEditorScreen({super.key, this.initial});

  final ClassSlotDraft? initial;

  static Future<ClassSlotDraft?> show(
    BuildContext context, {
    ClassSlotDraft? initial,
  }) {
    return Navigator.of(context).push<ClassSlotDraft>(
      MaterialPageRoute(
        builder: (_) => ClassSlotEditorScreen(initial: initial),
      ),
    );
  }

  @override
  State<ClassSlotEditorScreen> createState() => _ClassSlotEditorScreenState();
}

class _ClassSlotEditorScreenState extends State<ClassSlotEditorScreen> {
  String? _selectedDay;
  TimeOfDay? _start;
  TimeOfDay? _end;
  String _mode = 'Online';
  final TextEditingController _venueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _selectedDay = initial.day;
      _start = _parseTimeOfDay(initial.startTime);
      _end = _parseTimeOfDay(initial.endTime);
      _mode = initial.mode;
      _venueController.text = initial.venue ?? '';
    }
  }

  @override
  void dispose() {
    _venueController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String label) {
    final regex = RegExp(r'^(\d{1,2}):(\d{2}) (AM|PM)$');
    final match = regex.firstMatch(label.trim());
    if (match == null) return null;

    final hour12 = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final period = match.group(3);

    if (hour12 == null || minute == null || period == null) return null;

    int hour24;
    if (period == 'AM') {
      hour24 = hour12 % 12;
    } else {
      hour24 = (hour12 % 12) + 12;
    }

    return TimeOfDay(hour: hour24, minute: minute);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _end ?? (_start ?? TimeOfDay.now()),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final days = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final requiresVenue = _mode == 'Physical';
    final hasVenue = _venueController.text.trim().isNotEmpty;

    bool timeOrderValid = true;
    if (_start != null && _end != null) {
      final startMinutes = _start!.hour * 60 + _start!.minute;
      final endMinutes = _end!.hour * 60 + _end!.minute;
      timeOrderValid = endMinutes >= startMinutes;
    }

    final canSave = _selectedDay != null &&
        _start != null &&
        _end != null &&
        timeOrderValid &&
        (!requiresVenue || hasVenue);

    String timeLabel(TimeOfDay? t) {
      if (t == null) return 'Select time';
      return formatTime12h(DateTime(2000, 1, 1, t.hour, t.minute));
    }

    final isEdit = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Slot' : 'Add Slot'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownField<String>(
              label: 'Day',
              value: _selectedDay,
              hintText: 'Select day',
              items: days
                  .map(
                    (day) => DropdownMenuEntry<String>(
                      value: day,
                      label: day,
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedDay = value),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TapField(
                    label: 'Start time',
                    value: timeLabel(_start),
                    onTap: _pickStart,
                    hintText: 'Select time',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TapField(
                    label: 'End time',
                    value: timeLabel(_end),
                    onTap: _pickEnd,
                    hintText: 'Select time',
                  ),
                ),
              ],
            ),
            if (_start != null && _end != null && !timeOrderValid) ...[
              const SizedBox(height: 4),
              Text(
                'End time cannot be earlier than start time.',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text('Mode', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Column(
              children: [
                Row(
                  children: [
                    Radio<String>(
                      value: 'Online',
                      groupValue: _mode,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _mode = value);
                      },
                    ),
                    const Text('Online'),
                  ],
                ),
                Row(
                  children: [
                    Radio<String>(
                      value: 'Physical',
                      groupValue: _mode,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _mode = value);
                      },
                    ),
                    const Text('Physical'),
                  ],
                ),
              ],
            ),
            if (requiresVenue) ...[
              const SizedBox(height: AppSpacing.md),
              LabeledTextField(
                label: 'Venue',
                hintText: 'Enter venue',
                controller: _venueController,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: isEdit
                  ? ElevatedButton(
                      onPressed: canSave
                          ? () {
                              Navigator.pop(
                                context,
                                ClassSlotDraft(
                                  day: _selectedDay!,
                                  startTime: timeLabel(_start),
                                  endTime: timeLabel(_end),
                                  mode: _mode,
                                  venue: requiresVenue
                                      ? _venueController.text.trim()
                                      : null,
                                ),
                              );
                            }
                          : null,
                      child: const Text('Save slot'),
                    )
                  : ElevatedButton.icon(
                      onPressed: canSave
                          ? () {
                              Navigator.pop(
                                context,
                                ClassSlotDraft(
                                  day: _selectedDay!,
                                  startTime: timeLabel(_start),
                                  endTime: timeLabel(_end),
                                  mode: _mode,
                                  venue: requiresVenue
                                      ? _venueController.text.trim()
                                      : null,
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add slot'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

