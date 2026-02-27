import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../schedule/class_slot_sheet.dart';
import '../common/course_selector.dart';

class ClassForm extends StatelessWidget {
  const ClassForm({
    super.key,
    required this.courseCodes,
    required this.selectedCourseCode,
    required this.slots,
    required this.onCourseChanged,
    required this.onAddSlot,
    required this.onEditSlot,
    required this.onRemoveSlot,
  });

  final List<String> courseCodes;
  final String? selectedCourseCode;
  final List<ClassSlotDraft> slots;
  final ValueChanged<String?> onCourseChanged;
  final VoidCallback onAddSlot;
  final ValueChanged<ClassSlotDraft> onEditSlot;
  final ValueChanged<ClassSlotDraft> onRemoveSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourseSelector(
          courseCodes: courseCodes,
          selected: selectedCourseCode,
          onChanged: onCourseChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Class Slots',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        ...slots.map(
          (slot) => InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onEditSlot(slot),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${slot.day}\n',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppPrimarySwatch.shade900,
                                ),
                          ),
                          TextSpan(
                            text:
                                '${slot.startTime} - ${slot.endTime} · ${slot.mode}'
                                '${slot.venue == null ? '' : '\nVenue: ${slot.venue}'}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppPrimarySwatch.shade900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => onRemoveSlot(slot),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAddSlot,
            icon: const Icon(Icons.add),
            label: const Text('Add slot'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

