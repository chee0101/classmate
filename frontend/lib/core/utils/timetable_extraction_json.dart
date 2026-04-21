import 'dart:convert';

import '../models/class_type.dart';
import '../models/timetable_entry.dart';
import 'date_time_format.dart';

/// Parsed backend `/extract/timetable` envelope (subset).
class ParsedTimetableExtraction {
  ParsedTimetableExtraction({
    required this.documentKind,
    required this.warnings,
    required this.slotsByCourseCode,
  });

  final String documentKind;
  final List<String> warnings;
  final Map<String, List<TimetableSlot>> slotsByCourseCode;

  bool get hasSlots => slotsByCourseCode.isNotEmpty;
}

ClassType _parseClassType(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  switch (s) {
    case 'lecture':
      return ClassType.lecture;
    case 'tutorial':
      return ClassType.tutorial;
    case 'lab':
      return ClassType.lab;
    case 'other':
    default:
      return ClassType.other;
  }
}

String _mapBackendMode(String? mode, String? venue) {
  switch ((mode ?? '').trim().toLowerCase()) {
    case 'online':
      return 'Online';
    case 'physical':
      return 'Physical';
    case 'hybrid':
      return (venue != null && venue.trim().isNotEmpty) ? 'Physical' : 'Online';
    default:
      return 'Online';
  }
}

/// Builds [TimetableSlot]s with empty [classSlotId] for new saves.
TimetableSlot? timetableSlotFromExtractionMap(Map<String, dynamic> m) {
  final courseCode = (m['course_code'] as String?)?.trim().toUpperCase();
  final day = (m['day'] as String?)?.trim();
  final start = (m['start_minutes'] as num?)?.toInt();
  final end = (m['end_minutes'] as num?)?.toInt();
  if (courseCode == null ||
      courseCode.isEmpty ||
      day == null ||
      day.isEmpty ||
      start == null ||
      end == null ||
      end <= start) {
    return null;
  }

  final venue = (m['venue'] as String?)?.trim();
  final mode = _mapBackendMode(m['mode'] as String?, venue);
  final classType = _parseClassType(m['class_type'] as String?);

  return TimetableSlot(
    classSlotId: '',
    day: day,
    startTime: formatMinutes12h(start),
    endTime: formatMinutes12h(end),
    mode: mode,
    classType: classType,
    venue: venue != null && venue.isNotEmpty ? venue : null,
  );
}

ParsedTimetableExtraction? parseTimetableExtractionJson(String responseJson) {
  if (responseJson.trim().isEmpty) return null;
  try {
    final root = jsonDecode(responseJson) as Map<String, dynamic>;
    final kind = (root['document_kind'] as String?)?.trim() ?? '';
    final warningsRaw = root['warnings'];
    final warnings = <String>[];
    if (warningsRaw is List) {
      for (final w in warningsRaw) {
        if (w is String && w.trim().isNotEmpty) warnings.add(w.trim());
      }
    }

    final extraction = root['extraction'];
    if (extraction is! Map<String, dynamic>) {
      return ParsedTimetableExtraction(
        documentKind: kind,
        warnings: warnings,
        slotsByCourseCode: {},
      );
    }

    final timetable = extraction['timetable'];
    if (timetable is! Map<String, dynamic>) {
      return ParsedTimetableExtraction(
        documentKind: kind,
        warnings: warnings,
        slotsByCourseCode: {},
      );
    }

    final slotsRaw = timetable['slots'];
    if (slotsRaw is! List) {
      return ParsedTimetableExtraction(
        documentKind: kind,
        warnings: warnings,
        slotsByCourseCode: {},
      );
    }

    final byCourse = <String, List<TimetableSlot>>{};
    for (final item in slotsRaw) {
      if (item is! Map<String, dynamic>) continue;
      final slot = timetableSlotFromExtractionMap(item);
      if (slot == null) continue;
      final code = (item['course_code'] as String?)?.trim().toUpperCase() ?? '';
      if (code.isEmpty) continue;
      byCourse.putIfAbsent(code, () => <TimetableSlot>[]).add(slot);
    }

    for (final entry in byCourse.entries) {
      entry.value.sort((a, b) {
        final dayCmp = a.day.compareTo(b.day);
        if (dayCmp != 0) return dayCmp;
        return a.startTime.compareTo(b.startTime);
      });
    }

    return ParsedTimetableExtraction(
      documentKind: kind,
      warnings: warnings,
      slotsByCourseCode: byCourse,
    );
  } catch (_) {
    return null;
  }
}

bool sameTimetableSlotContent(TimetableSlot a, TimetableSlot b) {
  return a.day.trim() == b.day.trim() &&
      a.startTime.trim() == b.startTime.trim() &&
      a.endTime.trim() == b.endTime.trim() &&
      a.mode.trim() == b.mode.trim() &&
      a.classType == b.classType &&
      (a.venue ?? '').trim() == (b.venue ?? '').trim();
}

List<TimetableSlot> mergeTimetableSlots(
  List<TimetableSlot> existing,
  List<TimetableSlot> incoming,
) {
  final out = <TimetableSlot>[
    for (final s in existing)
      s.copyWith(classSlotId: s.classSlotId),
  ];
  for (final slot in incoming) {
    final normalized = slot.copyWith(classSlotId: '');
    if (!out.any((e) => sameTimetableSlotContent(e, normalized))) {
      out.add(normalized);
    }
  }
  out.sort((a, b) {
    final dayCmp = a.day.compareTo(b.day);
    if (dayCmp != 0) return dayCmp;
    return a.startTime.compareTo(b.startTime);
  });
  return out;
}
