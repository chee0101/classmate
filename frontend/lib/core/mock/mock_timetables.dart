import 'package:flutter/foundation.dart';

import '../models/timetable_entry.dart';

final ValueNotifier<List<TimetableEntry>> mockTimetablesNotifier =
    ValueNotifier<List<TimetableEntry>>([]);

List<TimetableEntry> timetablesForSessionAndTerm({
  required String sessionId,
  required String termId,
}) {
  return mockTimetablesNotifier.value
      .where((t) => t.sessionId == sessionId && t.termId == termId)
      .toList(growable: false);
}

bool hasTimetableForCourse({
  required String sessionId,
  required String termId,
  required String courseCode,
}) {
  final normalized = courseCode.trim().toUpperCase();
  return mockTimetablesNotifier.value.any(
    (t) =>
        t.sessionId == sessionId &&
        t.termId == termId &&
        t.courseCode.toUpperCase() == normalized,
  );
}

void upsertTimetableByCourse({
  required String sessionId,
  required String termId,
  required String courseCode,
  required List<TimetableSlot> slots,
}) {
  final normalized = courseCode.trim().toUpperCase();
  final existingIndex = mockTimetablesNotifier.value.indexWhere(
    (t) =>
        t.sessionId == sessionId &&
        t.termId == termId &&
        t.courseCode.toUpperCase() == normalized,
  );

  final next = List<TimetableEntry>.from(mockTimetablesNotifier.value);
  if (existingIndex == -1) {
    next.add(
      TimetableEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sessionId: sessionId,
        termId: termId,
        courseCode: normalized,
        slots: slots,
      ),
    );
  } else {
    next[existingIndex] = next[existingIndex].copyWith(
      slots: slots,
      courseCode: normalized,
    );
  }
  mockTimetablesNotifier.value = next;
}

void updateTimetableEntry({
  required String id,
  required String sessionId,
  required String termId,
  required String courseCode,
  required List<TimetableSlot> slots,
}) {
  final normalized = courseCode.trim().toUpperCase();
  final next = mockTimetablesNotifier.value.map((entry) {
    if (entry.id != id) return entry;
    return entry.copyWith(
      sessionId: sessionId,
      termId: termId,
      courseCode: normalized,
      slots: slots,
    );
  }).toList(growable: false);
  mockTimetablesNotifier.value = next;
}

void deleteTimetableEntry(String id) {
  mockTimetablesNotifier.value = mockTimetablesNotifier.value
      .where((entry) => entry.id != id)
      .toList(growable: false);
}

