import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Slot' : 'Add Slot'),
      ),
      body: ClassSlotEditorForm(
        initial: widget.initial,
        onSubmitted: (slot) => Navigator.pop(context, slot),
        addButtonText: 'Add slot',
        saveButtonText: 'Save slot',
      ),
    );
  }
}
