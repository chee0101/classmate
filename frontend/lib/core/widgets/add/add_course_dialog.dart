import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _isSaving = false;

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

  List<String> _parseCourseCodes(String input) {
    final tokens = input
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final seen = <String>{};
    final out = <String>[];
    for (final token in tokens) {
      if (seen.add(token)) {
        out.add(token);
      }
    }
    return out;
  }

  String _normalizeInput(String value) {
    return value.toUpperCase();
  }

  String _toHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final rawInput = _codeController.text.trim();

    if (rawInput.isEmpty) {
      setState(() => _errorText = 'Course code is required.');
      return;
    }

    if (widget.isEdit) {
      final code = rawInput.toUpperCase();
      final hex = _toHex(_colors[_selectedColorIndex]);
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

      setState(() => _isSaving = true);
      try {
        await updateCourse(
          id: course.id,
          sessionId: course.sessionId,
          termId: course.termId,
          courseCode: code,
          courseColor: hex,
        );
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
      Navigator.of(context).pop(code);
      return;
    }

    final parsedCodes = _parseCourseCodes(rawInput);
    if (parsedCodes.isEmpty) {
      setState(() => _errorText = 'Course code is required.');
      return;
    }

    final existingCodes = courseCodesForSessionAndTerm(
      sessionId: widget.sessionId,
      termId: widget.termId,
    ).toSet();
    final newCodes = parsedCodes.where((c) => !existingCodes.contains(c)).toList();

    if (newCodes.isEmpty) {
      setState(() => _errorText = 'All entered course codes already exist.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (newCodes.length == 1) {
        final hex = _toHex(_colors[_selectedColorIndex]);
        await addCourse(
          sessionId: widget.sessionId,
          termId: widget.termId,
          courseCode: newCodes.first,
          courseColor: hex,
        );
      } else {
        final existingCount = coursesForSessionAndTerm(
          sessionId: widget.sessionId,
          termId: widget.termId,
        ).length;
        for (var i = 0; i < newCodes.length; i++) {
          final color = _colors[(existingCount + i) % _colors.length];
          await addCourse(
            sessionId: widget.sessionId,
            termId: widget.termId,
            courseCode: newCodes[i],
            courseColor: _toHex(color),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    if (!mounted) return;
    final addedText = newCodes.length == 1
        ? 'Course ${newCodes.first} added.'
        : '${newCodes.length} courses added.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(addedText)),
    );
    Navigator.of(context).pop(newCodes.first);
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
              label: widget.isEdit ? 'Course Code' : 'Course Code(s)',
              hintText: widget.isEdit
                  ? 'Enter course code'
                  : 'e.g. CSC101, MTH120, PHY103',
              controller: _codeController,
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return newValue.copyWith(text: _normalizeInput(newValue.text));
                }),
              ],
              errorText: _errorText,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            if (!widget.isEdit) ...[
              const SizedBox(height: 6),
              Text(
                'Tip: Add multiple courses using commas or new lines.',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
            if (widget.isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Color Tag',
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ColorPicker(
                colors: _colors,
                selectedIndex: _selectedColorIndex,
                onSelect: (index) {
                  setState(() => _selectedColorIndex = index);
                },
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
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