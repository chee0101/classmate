import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../utils/date_time_format.dart';
import '../../utils/term_windows.dart';
import '../common/form_fields.dart';

class EventForm extends StatelessWidget {
  const EventForm({
    super.key,
    required this.eventNameController,
    required this.allDay,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.hideClassesInEvent,
    required this.selectedTerm,
    required this.datesValid,
    required this.timesValid,
    required this.onAllDayChanged,
    required this.onNameChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onHideClassesChanged,
  });

  final TextEditingController eventNameController;
  final bool allDay;
  final DateTime startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool hideClassesInEvent;
  final TermWindow selectedTerm;
  final bool datesValid;
  final bool timesValid;
  final ValueChanged<bool> onAllDayChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;
  final ValueChanged<bool> onHideClassesChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: 'Event Name',
          hintText: 'Enter event',
          controller: eventNameController,
          onChanged: onNameChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              'All day event',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            Switch(
              value: allDay,
              onChanged: onAllDayChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TapField(
                label: 'Start date',
                value: formatDateDdMmYyyy(startDate),
                onTap: onPickStartDate,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (!allDay)
              Expanded(
                child: TapField(
                  label: 'Start time',
                  value: startTime == null
                      ? 'Select time'
                      : formatTime12h(
                          DateTime(
                            2000,
                            1,
                            1,
                            startTime!.hour,
                            startTime!.minute,
                          ),
                        ),
                  onTap: onPickStartTime,
                  hintText: 'Select time',
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TapField(
                label: 'End date',
                value: endDate == null
                    ? 'Select date'
                    : formatDateDdMmYyyy(endDate!),
                onTap: onPickEndDate,
                hintText: 'Select date',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (!allDay)
              Expanded(
                child: TapField(
                  label: 'End time',
                  value: endTime == null
                      ? 'Select time'
                      : formatTime12h(
                          DateTime(
                            2000,
                            1,
                            1,
                            endTime!.hour,
                            endTime!.minute,
                          ),
                        ),
                  onTap: onPickEndTime,
                  hintText: 'Select time',
                ),
              ),
          ],
        ),
        if (!datesValid) ...[
          const SizedBox(height: 4),
          Text(
            'Event dates must be within ${selectedTerm.label} and end date cannot be before start date.',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
            ),
          ),
        ],
        if (!allDay && !timesValid) ...[
          const SizedBox(height: 4),
          Text(
            'End time cannot be earlier than start time.',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Checkbox(
              value: hideClassesInEvent,
              onChanged: (value) {
                if (value == null) return;
                onHideClassesChanged(value);
              },
            ),
            const Expanded(
              child: Text('Hide classes during this event'),
            ),
          ],
        ),
      ],
    );
  }
}

