import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../mock/mock_courses.dart';
import '../common/form_fields.dart';

class AddCourseDialog extends StatefulWidget {
  const AddCourseDialog({
    super.key,
    required this.sessionId,
    required this.termId,
  });

  final String sessionId;
  final String termId;

  static Future<String?> show(
    BuildContext context, {
    required String sessionId,
    required String termId,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddCourseDialog(sessionId: sessionId, termId: termId),
    );
  }

  @override
  State<AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends State<AddCourseDialog> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;
  int _selectedColorIndex = 0;

  final List<Color> _colors = const [
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFFF97316), // orange
    Color(0xFFEAB308), // yellow
    Color(0xFF6366F1), // indigo
    Color(0xFFEF4444), // red
    Color(0xFF14B8A6), // teal
    Color(0xFFEC4899), // pink
  ];

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

    if (courseCodeExistsInSessionAndTerm(
      sessionId: widget.sessionId,
      termId: widget.termId,
      courseCode: code,
    )) {
      setState(() => _errorText = 'This course code already exists.');
      return;
    }

    final color = _colors[_selectedColorIndex];
    final hex =
        '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    addCourse(
      sessionId: widget.sessionId,
      termId: widget.termId,
      courseCode: code,
      courseColor: hex,
    );

    Navigator.of(context).pop(code.trim().toUpperCase());
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
                'Add Course',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(_colors.length, (index) {
                final color = _colors[index];
                final selected = index == _selectedColorIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedColorIndex = index);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: selected
                            ? Border.all(
                                color: Colors.black.withOpacity(0.6),
                                width: 2,
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSave,
                child: const Text('Add course'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

