import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/widgets/schedule/class_slot_sheet.dart';

enum ClassEditApplyScope { thisClassOnly, allClasses }

class ClassEditResult {
  const ClassEditResult({
    required this.updatedDraft,
    required this.applyScope,
  });

  final ClassSlotDraft updatedDraft;
  final ClassEditApplyScope applyScope;
}

class ScheduleClassEditorScreen extends StatefulWidget {
  const ScheduleClassEditorScreen({
    super.key,
    required this.initialDraft,
  });

  final ClassSlotDraft initialDraft;

  static Future<ClassEditResult?> show(
    BuildContext context, {
    required ClassSlotDraft initialDraft,
  }) {
    return Navigator.of(context).push<ClassEditResult>(
      MaterialPageRoute(
        builder: (_) => ScheduleClassEditorScreen(initialDraft: initialDraft),
      ),
    );
  }

  @override
  State<ScheduleClassEditorScreen> createState() => _ScheduleClassEditorScreenState();
}

class _ScheduleClassEditorScreenState extends State<ScheduleClassEditorScreen> {
  ClassEditApplyScope _applyScope = ClassEditApplyScope.thisClassOnly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Class')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Apply changes to',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          RadioListTile<ClassEditApplyScope>(
            title: const Text('This class only'),
            value: ClassEditApplyScope.thisClassOnly,
            groupValue: _applyScope,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _applyScope = value);
            },
          ),
          RadioListTile<ClassEditApplyScope>(
            title: const Text('All classes'),
            value: ClassEditApplyScope.allClasses,
            groupValue: _applyScope,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _applyScope = value);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: ClassSlotEditorForm(
              initial: widget.initialDraft,
              dayAsDate: _applyScope == ClassEditApplyScope.thisClassOnly,
              showTitle: false,
              saveButtonText: 'Save changes',
              onSubmitted: (slot) {
                Navigator.of(context).pop(
                  ClassEditResult(
                    updatedDraft: slot,
                    applyScope: _applyScope,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
