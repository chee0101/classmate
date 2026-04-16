import 'dart:convert';

class ParsedExtractedSubtask {
  ParsedExtractedSubtask({
    required this.title,
    required this.dueDateTime,
    this.note,
  });

  String title;
  DateTime? dueDateTime;
  String? note;
}

class ParsedExtractedTask {
  ParsedExtractedTask({
    required this.title,
    required this.dueDateTime,
    required this.courseCode,
    required this.subtasks,
    this.note,
  });

  String title;
  DateTime? dueDateTime;
  String courseCode;
  String? note;
  final List<ParsedExtractedSubtask> subtasks;
}

class ParsedTaskExtractionEnvelope {
  ParsedTaskExtractionEnvelope({
    required this.tasks,
    this.confidence,
    this.notes,
  });

  final List<ParsedExtractedTask> tasks;
  final double? confidence;
  final String? notes;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return null;
  // Always normalize extracted datetimes to device local timezone so
  // review labels and saved due dates follow the user's phone time.
  return parsed.toLocal();
}

String _cleanText(dynamic value) {
  if (value is! String) return '';
  return value.trim();
}

ParsedTaskExtractionEnvelope? tryParseTaskExtractionEnvelope(String jsonStr) {
  try {
    final root = jsonDecode(jsonStr) as Map<String, dynamic>?;
    if (root == null) return null;
    final extraction = root['extraction'] as Map<String, dynamic>?;
    if (extraction == null) return null;

    final tasksRaw = extraction['tasks'] as List<dynamic>? ?? const [];
    final parsedTasks = <ParsedExtractedTask>[];

    for (final rawTask in tasksRaw) {
      final taskMap = rawTask as Map<String, dynamic>;
      final title = _cleanText(taskMap['title']);
      if (title.isEmpty) continue;

      final courseCode = _cleanText(taskMap['course_code']);
      final subtasksRaw = taskMap['subtasks'] as List<dynamic>? ?? const [];
      final subtasks = <ParsedExtractedSubtask>[];
      for (final rawSubtask in subtasksRaw) {
        final subtaskMap = rawSubtask as Map<String, dynamic>;
        final subtaskTitle = _cleanText(subtaskMap['title']);
        if (subtaskTitle.isEmpty) continue;
        final note =
            _cleanText(subtaskMap['description']).isEmpty
                ? _cleanText(subtaskMap['note'])
                : _cleanText(subtaskMap['description']);
        subtasks.add(
          ParsedExtractedSubtask(
            title: subtaskTitle,
            dueDateTime: _parseDateTime(subtaskMap['due_datetime']),
            note: note.isEmpty ? null : note,
          ),
        );
      }

      final note =
          _cleanText(taskMap['description']).isEmpty
              ? _cleanText(taskMap['note'])
              : _cleanText(taskMap['description']);

      parsedTasks.add(
        ParsedExtractedTask(
          title: title,
          dueDateTime: _parseDateTime(taskMap['due_datetime']),
          courseCode: courseCode.isEmpty ? '' : courseCode.toUpperCase(),
          note: note.isEmpty ? null : note,
          subtasks: subtasks,
        ),
      );
    }

    final confidenceRaw = extraction['confidence'];
    final notes = _cleanText(extraction['notes']);
    return ParsedTaskExtractionEnvelope(
      tasks: parsedTasks,
      confidence: confidenceRaw is num ? confidenceRaw.toDouble() : null,
      notes: notes.isEmpty ? null : notes,
    );
  } catch (_) {
    return null;
  }
}
