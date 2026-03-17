import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../services/course_store.dart';
import '../../models/course.dart';
import '../common/form_fields.dart';
import '../common/color_picker.dart';

class CourseDialog extends StatefulWidget {
  const CourseDialog({
    super.key,
    required this.sessionId,
    required this.termId,
    this.course,
  });

  final String sessionId;
  final String termId;
  final Course? course;

  bool get isEdit => course != null;

  static Future<String?> show(
    BuildContext context, {
    required String sessionId,
    required String termId,
    Course? course,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CourseDialog(
        sessionId: sessionId,
        termId: termId,
        course: course,
      ),
    );
  }

  @override
  State<CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends State<CourseDialog> {
  late final TextEditingController _codeController;
  String? _errorText;
  int _selectedColorIndex = 0;

  final List<Color> _colors = const [
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF6366F1),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      final course = widget.course!;

      _codeController =
          TextEditingController(text: course.courseCode);

      final colorValue = int.tryParse(
        course.courseColor.replaceFirst('#', '0xFF'),
      );

      final currentColor = Color(colorValue ?? _colors.first.value);

      final index = _colors.indexWhere(
        (c) => c.value == currentColor.value,
      );

      _selectedColorIndex = index == -1 ? 0 : index;
    } else {
      _codeController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _errorText = 'Course code is required.');
      return;
    }

    final color = _colors[_selectedColorIndex];
    final hex =
        '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    if (widget.isEdit) {
      final course = widget.course!;

      if (courseCodeExistsInSessionAndTermExcludingCourse(
        sessionId: course.sessionId,
        termId: course.termId,
        courseId: course.id,
        courseCode: code,
      )) {
        setState(() => _errorText = 'This course code already exists.');
        return;
      }

      updateCourse(
        id: course.id,
        sessionId: course.sessionId,
        termId: course.termId,
        courseCode: code,
        courseColor: hex,
      );
    } else {
      if (courseCodeExistsInSessionAndTerm(
        sessionId: widget.sessionId,
        termId: widget.termId,
        courseCode: code,
      )) {
        setState(() => _errorText = 'This course code already exists.');
        return;
      }

      addCourse(
        sessionId: widget.sessionId,
        termId: widget.termId,
        courseCode: code,
        courseColor: hex,
      );
    }

    Navigator.of(context).pop(code.toUpperCase()); // ✅ RETURN VALUE
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                widget.isEdit ? 'Edit Course' : 'Add Course',
                style: textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledTextField(
              label: 'Course Code',
              hintText: 'Enter course code',
              controller: _codeController,
              errorText: _errorText,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Color Tag',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 8),

            /// ✅ Reusable Color Picker
            ColorPicker(
              colors: _colors,
              selectedIndex: _selectedColorIndex,
              onSelect: (index) {
                setState(() => _selectedColorIndex = index);
              },
            ),

            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSave,
                child: Text(
                  widget.isEdit ? 'Save changes' : 'Add course',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}