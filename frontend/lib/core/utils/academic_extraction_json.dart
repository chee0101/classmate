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

String _sessionNameFrom(Map<String, dynamic> session) {
  final fromName = (session['name'] as String?)?.trim() ?? '';
  if (fromName.isNotEmpty) return fromName;
  return (session['session_name'] as String?)?.trim() ?? '';
}

DateTime? _tryParseDate(dynamic v) {
  if (v == null) return null;
  if (v is! String || v.trim().isEmpty) return null;
  return DateTime.tryParse(v.trim());
}

DateTime _sessionStartFrom(
  Map<String, dynamic> session,
  List<ParsedExtractedEvent> eventsFromDates,
) {
  final direct = _tryParseDate(session['start_date'] ?? session['session_start']);
  if (direct != null) return direct;
  if (eventsFromDates.isNotEmpty) {
    return eventsFromDates
        .map((e) => e.startDateTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }
  throw const FormatException('Missing session start');
}

DateTime _sessionEndFrom(
  Map<String, dynamic> session,
  List<ParsedExtractedEvent> eventsFromDates,
) {
  final direct = _tryParseDate(session['end_date'] ?? session['session_end']);
  if (direct != null) return direct;
  if (eventsFromDates.isNotEmpty) {
    return eventsFromDates
        .map((e) => e.endDateTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
  throw const FormatException('Missing session end');
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

    final name = _sessionNameFrom(session);

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

      DateTime startDateTime;
      DateTime endDateTime;
      final startDtRaw = m['start_datetime'];
      final endDtRaw = m['end_datetime'];
      if (startDtRaw is String &&
          startDtRaw.trim().isNotEmpty &&
          endDtRaw is String &&
          endDtRaw.trim().isNotEmpty) {
        startDateTime = _parseDateTime(startDtRaw);
        endDateTime = _parseDateTime(endDtRaw);
      } else {
        final sd = m['start_date'] ?? m['start_datetime'];
        final ed = m['end_date'] ?? m['end_datetime'];
        final startDay = _parseDate(sd);
        final endDay = _parseDate(ed);
        startDateTime = DateTime(startDay.year, startDay.month, startDay.day);
        endDateTime = DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59, 999);
      }

      events.add(
        ParsedExtractedEvent(
          title: title,
          startDateTime: startDateTime,
          endDateTime: endDateTime,
          allDay: m['all_day'] as bool? ?? true,
          hideClassesDuringEvent:
              m['hide_classes_during_event'] as bool? ?? true,
          isAcademicBreak: m['is_academic_break'] as bool? ?? false,
          termId: (m['term_id'] as String?)?.trim() ?? 'sem1',
          location: (m['location'] as String?)?.trim(),
        ),
      );
    }

    final start = _sessionStartFrom(session, events);
    final end = _sessionEndFrom(session, events);

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
