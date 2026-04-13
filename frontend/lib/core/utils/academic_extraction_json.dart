import 'dart:convert';

import '../models/academic_session.dart';

/// Parsed payload from `POST /extract/academic-calendar` (`AcademicExtractionEnvelope`).
class ParsedAcademicExtraction {
  ParsedAcademicExtraction({
    required this.sessionName,
    required this.sessionStart,
    required this.sessionEnd,
    required this.terms,
    required this.events,
    this.confidence,
    this.notes,
  });

  final String sessionName;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final List<SessionTerm> terms;
  final List<ParsedExtractedEvent> events;
  final double? confidence;
  final String? notes;
}

class ParsedExtractedEvent {
  ParsedExtractedEvent({
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    required this.allDay,
    required this.hideClassesDuringEvent,
    required this.isAcademicBreak,
    required this.termId,
    this.location,
  });

  String title;
  DateTime startDateTime;
  DateTime endDateTime;
  bool allDay;
  bool hideClassesDuringEvent;
  bool isAcademicBreak;
  String termId;
  String? location;
}

DateTime _parseDate(dynamic v) {
  if (v is String) {
    return DateTime.parse(v);
  }
  throw FormatException('Expected date string, got $v');
}

DateTime _parseDateTime(dynamic v) {
  if (v is String) {
    return DateTime.parse(v);
  }
  throw FormatException('Expected datetime string, got $v');
}

/// Returns `null` if JSON is invalid or [extraction.academic_session] is missing.
ParsedAcademicExtraction? tryParseAcademicExtractionEnvelope(String jsonStr) {
  try {
    final root = jsonDecode(jsonStr) as Map<String, dynamic>?;
    if (root == null) return null;
    final extraction = root['extraction'] as Map<String, dynamic>?;
    if (extraction == null) return null;
    final session = extraction['academic_session'] as Map<String, dynamic>?;
    if (session == null) return null;

    final name = (session['name'] as String?)?.trim() ?? '';
    final start = _parseDate(session['start_date']);
    final end = _parseDate(session['end_date']);

    final termsRaw = session['terms'] as List<dynamic>? ?? const [];
    final terms = <SessionTerm>[];
    for (final t in termsRaw) {
      final m = t as Map<String, dynamic>;
      final id = (m['id'] as String?)?.trim() ?? '';
      final label = (m['label'] as String?)?.trim() ?? '';
      if (id.isEmpty || label.isEmpty) continue;
      terms.add(
        SessionTerm(
          id: id,
          label: label,
          start: _parseDate(m['start_date']),
          end: _parseDate(m['end_date']),
        ),
      );
    }

    final eventsRaw = session['events'] as List<dynamic>? ?? const [];
    final events = <ParsedExtractedEvent>[];
    for (final e in eventsRaw) {
      final m = e as Map<String, dynamic>;
      final title = (m['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      events.add(
        ParsedExtractedEvent(
          title: title,
          startDateTime: _parseDateTime(m['start_datetime']),
          endDateTime: _parseDateTime(m['end_datetime']),
          allDay: m['all_day'] as bool? ?? true,
          hideClassesDuringEvent:
              m['hide_classes_during_event'] as bool? ?? true,
          isAcademicBreak: m['is_academic_break'] as bool? ?? false,
          termId: (m['term_id'] as String?)?.trim() ?? 'sem1',
          location: (m['location'] as String?)?.trim(),
        ),
      );
    }

    final conf = extraction['confidence'];
    final notes = extraction['notes'] as String?;

    return ParsedAcademicExtraction(
      sessionName: name.isEmpty ? '${start.year}/${end.year}' : name,
      sessionStart: start,
      sessionEnd: end,
      terms: terms,
      events: events,
      confidence: conf is num ? conf.toDouble() : null,
      notes: notes,
    );
  } catch (_) {
    return null;
  }
}
