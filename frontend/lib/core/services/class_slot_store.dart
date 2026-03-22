import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/weekdays.dart';
import '../models/class_type.dart';
import '../models/timetable_entry.dart';
import '../utils/course_display.dart';
import '../utils/date_time_format.dart';
import 'course_store.dart';

final ValueNotifier<List<TimetableEntry>> timetablesNotifier =
    ValueNotifier<List<TimetableEntry>>([]);

StreamSubscription<User?>? _authSubscription;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _slotsSubscription;

CollectionReference<Map<String, dynamic>> _classSlotsCollection(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection(
    'classSlots',
  );
}

CollectionReference<Map<String, dynamic>> _coursesCollection(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection(
    'courses',
  );
}

String _buildScopedKey({
  required String sessionId,
  required String termId,
  required String courseCode,
}) {
  return '${sessionId.trim()}::${termId.trim()}::${courseCode.trim().toUpperCase()}';
}

void initializeClassSlotsSync() {
  if (_authSubscription != null) return;

  _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
    _slotsSubscription?.cancel();
    _slotsSubscription = null;

    if (user == null) {
      timetablesNotifier.value = const <TimetableEntry>[];
      return;
    }

    _slotsSubscription = _classSlotsCollection(user.uid).snapshots().listen((
      snapshot,
    ) {
      timetablesNotifier.value = _mapSlotDocsToTimetableEntries(snapshot.docs);
    });
  });
}

List<TimetableEntry> _mapSlotDocsToTimetableEntries(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final courses = coursesNotifier.value;
  final grouped = <String, _EntryBuilder>{};
  for (final doc in docs) {
    final data = doc.data();
    final sessionId = (data['sessionId'] as String?)?.trim() ?? '';
    final termId = (data['termId'] as String?)?.trim() ?? '';
    if (sessionId.isEmpty || termId.isEmpty) continue;

    final storedCourseCode =
        (data['courseCode'] as String?)?.trim().toUpperCase() ?? '';
    final rawCourseId = (data['courseId'] as String?)?.trim();
    final effectiveCourseId =
        (rawCourseId != null && rawCourseId.isNotEmpty) ? rawCourseId : null;

    final String groupKey;
    if (effectiveCourseId != null) {
      groupKey = effectiveCourseId;
    } else {
      final fallbackKey = (data['timetableScopedKey'] as String?)?.trim();
      groupKey = (fallbackKey != null && fallbackKey.isNotEmpty)
          ? fallbackKey
          : (storedCourseCode.isNotEmpty
                ? _buildScopedKey(
                    sessionId: sessionId,
                    termId: termId,
                    courseCode: storedCourseCode,
                  )
                : '');
    }
    if (groupKey.isEmpty) continue;

    final displayCode = displayCourseCodeForTimetableData(
      courseId: effectiveCourseId,
      storedCourseCode: storedCourseCode,
      courses: courses,
    );
    if (displayCode.isEmpty) continue;

    final slot = _slotFromMap(data, fallbackClassSlotId: doc.id);
    if (slot == null) continue;

    grouped.putIfAbsent(
      groupKey,
      () => _EntryBuilder(
        id: groupKey,
        sessionId: sessionId,
        termId: termId,
        courseId: effectiveCourseId,
        courseCode: displayCode,
      ),
    );
    grouped[groupKey]!.slots.add(slot);
  }

  final entries = grouped.values.map((builder) {
    builder.sortSlots();
    return TimetableEntry(
      id: builder.id,
      sessionId: builder.sessionId,
      termId: builder.termId,
      courseId: builder.courseId,
      courseCode: builder.courseCode,
      slots: builder.slots,
    );
  }).toList(growable: false);

  entries.sort((a, b) {
    final sessionCompare = a.sessionId.compareTo(b.sessionId);
    if (sessionCompare != 0) return sessionCompare;
    final termCompare = a.termId.compareTo(b.termId);
    if (termCompare != 0) return termCompare;
    return a.courseCode.compareTo(b.courseCode);
  });

  return entries;
}

TimetableEntry? _findTimetableEntryForCourse({
  required String sessionId,
  required String termId,
  required String normalizedCourseCode,
}) {
  final resolvedId = resolveCourseIdByCodeInSessionAndTerm(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCourseCode,
  );
  for (final item in timetablesNotifier.value) {
    if (item.sessionId != sessionId || item.termId != termId) continue;
    if (resolvedId != null &&
        item.courseId != null &&
        item.courseId == resolvedId) {
      return item;
    }
  }
  for (final item in timetablesNotifier.value) {
    if (item.sessionId == sessionId &&
        item.termId == termId &&
        item.courseCode.toUpperCase() == normalizedCourseCode) {
      return item;
    }
  }
  return null;
}

TimetableSlot? _slotFromMap(
  Map<String, dynamic> data, {
  required String fallbackClassSlotId,
}) {
  final day = (data['day'] as String?)?.trim();
  final startMinutes = (data['startMinutes'] as num?)?.toInt();
  final endMinutes = (data['endMinutes'] as num?)?.toInt();
  final mode = (data['mode'] as String?)?.trim();
  final classTypeRaw = (data['classType'] as String?)?.trim().toLowerCase();

  if (day == null ||
      day.isEmpty ||
      startMinutes == null ||
      endMinutes == null ||
      mode == null ||
      mode.isEmpty) {
    return null;
  }
  if (endMinutes <= startMinutes) return null;

  return TimetableSlot(
    classSlotId: ((data['classSlotId'] as String?)?.trim().isNotEmpty ?? false)
        ? (data['classSlotId'] as String).trim()
        : fallbackClassSlotId,
    day: day,
    startTime: _formatMinutes12h(startMinutes),
    endTime: _formatMinutes12h(endMinutes),
    mode: mode,
    classType: _parseClassType(classTypeRaw),
    venue: (data['venue'] as String?)?.trim(),
  );
}

ClassType _parseClassType(String? raw) {
  if (raw == null || raw.isEmpty) return ClassType.other;
  for (final type in ClassType.values) {
    if (type.name == raw) return type;
  }
  return ClassType.other;
}

int? _parseMinutes12h(String value) => parseTimeLabel12hToMinutes(value);

String _formatMinutes12h(int minutes) => formatMinutes12h(minutes);

Future<void> upsertTimetableByCourse({
  required String sessionId,
  required String termId,
  required String courseCode,
  required List<TimetableSlot> slots,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final normalizedCourseCode = courseCode.trim().toUpperCase();
  final courseId = await _resolveCourseId(
    uid: user.uid,
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCourseCode,
  );
  if (courseId == null) {
    debugPrint(
      'Skipped saving class slot because courseId could not be resolved '
      'for $normalizedCourseCode in $sessionId/$termId.',
    );
    return;
  }
  final scopedKey = _buildScopedKey(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCourseCode,
  );

  var existing = await _classSlotsCollection(user.uid)
      .where('courseId', isEqualTo: courseId)
      .get();
  if (existing.docs.isEmpty) {
    existing = await _classSlotsCollection(user.uid)
        .where('timetableScopedKey', isEqualTo: scopedKey)
        .get();
  }

  final incomingSlots = slots
      .map(_SlotPayload.fromTimetableSlot)
      .whereType<_SlotPayload>()
      .toList(growable: false);
  final existingSlots = existing.docs
      .map(_PersistedSlot.fromDoc)
      .toList(growable: false);

  final matchedExisting = <int>{};
  final matchedIncoming = <int>{};
  final batch = FirebaseFirestore.instance.batch();
  var hasChanges = false;

  // Pass 1: exact slot matches -> no write.
  for (var incomingIndex = 0; incomingIndex < incomingSlots.length; incomingIndex++) {
    final incoming = incomingSlots[incomingIndex];
    for (var existingIndex = 0; existingIndex < existingSlots.length; existingIndex++) {
      if (matchedExisting.contains(existingIndex)) continue;
      final existingSlot = existingSlots[existingIndex];
      if (existingSlot.payload == null) continue;
      if (existingSlot.payload!.exactKey == incoming.exactKey) {
        matchedExisting.add(existingIndex);
        matchedIncoming.add(incomingIndex);
        break;
      }
    }
  }

  final remainingIncoming = <_SlotPayload>[];
  for (var i = 0; i < incomingSlots.length; i++) {
    if (!matchedIncoming.contains(i)) remainingIncoming.add(incomingSlots[i]);
  }

  final remainingExisting = <_PersistedSlot>[];
  final invalidExisting = <_PersistedSlot>[];
  for (var i = 0; i <existingSlots.length; i++) {
    if (matchedExisting.contains(i)) continue;
    final existingSlot = existingSlots[i];
    if (existingSlot.payload == null) {
      invalidExisting.add(existingSlot);
    } else {
      remainingExisting.add(existingSlot);
    }
  }

  remainingIncoming.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  remainingExisting.sort((a, b) {
    final aKey = a.payload?.sortKey ?? '';
    final bKey = b.payload?.sortKey ?? '';
    return aKey.compareTo(bKey);
  });

  final sharedCount = remainingIncoming.length < remainingExisting.length
      ? remainingIncoming.length
      : remainingExisting.length;

  // Pass 2: reuse existing doc IDs for modified slots.
  for (var i = 0; i < sharedCount; i++) {
    final existingSlot = remainingExisting[i];
    final incomingSlot = remainingIncoming[i];
    batch.set(
      existingSlot.doc.reference,
      _slotWriteData(
        sessionId: sessionId,
        termId: termId,
        courseId: courseId,
        courseCode: normalizedCourseCode,
        scopedKey: scopedKey,
        classSlotId: incomingSlot.classSlotId.isEmpty
            ? (existingSlot.payload?.classSlotId ?? existingSlot.doc.id)
            : incomingSlot.classSlotId,
        slot: incomingSlot,
        includeCreatedAt: false,
      ),
      SetOptions(merge: true),
    );
    hasChanges = true;
  }

  // Pass 3: create additional slots.
  for (var i = sharedCount; i < remainingIncoming.length; i++) {
    final ref = _classSlotsCollection(user.uid).doc();
    batch.set(
      ref,
      _slotWriteData(
        sessionId: sessionId,
        termId: termId,
        courseId: courseId,
        courseCode: normalizedCourseCode,
        scopedKey: scopedKey,
        classSlotId: remainingIncoming[i].classSlotId.isEmpty
            ? ref.id
            : remainingIncoming[i].classSlotId,
        slot: remainingIncoming[i],
        includeCreatedAt: true,
      ),
    );
    hasChanges = true;
  }

  // Pass 4: delete extra or invalid persisted slots.
  for (var i = sharedCount; i < remainingExisting.length; i++) {
    batch.delete(remainingExisting[i].doc.reference);
    hasChanges = true;
  }
  for (final invalid in invalidExisting) {
    batch.delete(invalid.doc.reference);
    hasChanges = true;
  }

  if (!hasChanges) return;
  await batch.commit();
}

Future<String?> _resolveCourseId({
  required String uid,
  required String sessionId,
  required String termId,
  required String courseCode,
}) async {
  for (final course in coursesNotifier.value) {
    if (course.sessionId == sessionId &&
        course.termId == termId &&
        course.courseCode.toUpperCase() == courseCode.toUpperCase()) {
      return course.id;
    }
  }

  final scopedKey = _buildScopedKey(
    sessionId: sessionId,
    termId: termId,
    courseCode: courseCode,
  );
  final snapshot = await _coursesCollection(uid)
      .where('courseScopedKey', isEqualTo: scopedKey)
      .limit(1)
      .get();
  if (snapshot.docs.isNotEmpty) {
    return snapshot.docs.first.id;
  }
  return null;
}

Future<void> updateTimetableEntry({
  required String id,
  required String sessionId,
  required String termId,
  required String courseCode,
  required List<TimetableSlot> slots,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final normalizedCode = courseCode.trim().toUpperCase();
  final newCourseId = await _resolveCourseId(
    uid: user.uid,
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCode,
  );
  if (newCourseId == null) return;

  if (id.contains('::')) {
    final newScopedKey = _buildScopedKey(
      sessionId: sessionId,
      termId: termId,
      courseCode: normalizedCode,
    );
    if (id != newScopedKey) {
      await deleteTimetableEntry(id);
    }
  } else if (id != newCourseId) {
    await deleteTimetableEntry(id);
  }
  await upsertTimetableByCourse(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCode,
    slots: slots,
  );
}

Map<String, dynamic> _slotWriteData({
  required String sessionId,
  required String termId,
  required String courseId,
  required String courseCode,
  required String scopedKey,
  required String classSlotId,
  required _SlotPayload slot,
  required bool includeCreatedAt,
}) {
  final data = <String, dynamic>{
    'sessionId': sessionId.trim(),
    'termId': termId.trim(),
    'courseId': courseId,
    'courseCode': courseCode,
    'timetableScopedKey': scopedKey,
    'classSlotId': classSlotId.trim(),
    'day': slot.day,
    'startMinutes': slot.startMinutes,
    'endMinutes': slot.endMinutes,
    'mode': slot.mode,
    'venue': slot.venue.isEmpty ? null : slot.venue,
    'classType': slot.classType.name,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (includeCreatedAt) {
    data['createdAt'] = FieldValue.serverTimestamp();
  }
  return data;
}

Future<void> deleteTimetableEntry(String id) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  QuerySnapshot<Map<String, dynamic>> snapshot;
  if (id.contains('::')) {
    snapshot = await _classSlotsCollection(user.uid)
        .where('timetableScopedKey', isEqualTo: id)
        .get();
  } else {
    snapshot = await _classSlotsCollection(user.uid)
        .where('courseId', isEqualTo: id)
        .get();
    if (snapshot.docs.isEmpty) {
      snapshot = await _classSlotsCollection(user.uid)
          .where('timetableScopedKey', isEqualTo: id)
          .get();
    }
  }
  if (snapshot.docs.isEmpty) return;

  final batch = FirebaseFirestore.instance.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}

int? parseTimeLabelToMinutes(String value) => _parseMinutes12h(value);

Future<void> updateClassSlotSeries({
  required String sessionId,
  required String termId,
  required String courseCode,
  required String sourceDay,
  required int sourceStartMinutes,
  required int sourceEndMinutes,
  required TimetableSlot replacement,
}) async {
  final normalizedCourseCode = courseCode.trim().toUpperCase();
  final entry = _findTimetableEntryForCourse(
    sessionId: sessionId,
    termId: termId,
    normalizedCourseCode: normalizedCourseCode,
  );
  if (entry == null) return;

  var replaced = false;
  final updatedSlots = entry.slots.map((slot) {
    final start = _parseMinutes12h(slot.startTime);
    final end = _parseMinutes12h(slot.endTime);
    if (start == null || end == null) return slot;
    if (slot.day.trim().toLowerCase() == sourceDay.trim().toLowerCase() &&
        start == sourceStartMinutes &&
        end == sourceEndMinutes) {
      replaced = true;
      return replacement;
    }
    return slot;
  }).toList(growable: false);

  if (!replaced) return;
  await upsertTimetableByCourse(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCourseCode,
    slots: updatedSlots,
  );
}

Future<void> updateClassSlotSeriesById({
  required String sessionId,
  required String termId,
  required String courseCode,
  required String classSlotId,
  required TimetableSlot replacement,
}) async {
  final normalizedCourseCode = courseCode.trim().toUpperCase();
  final entry = _findTimetableEntryForCourse(
    sessionId: sessionId,
    termId: termId,
    normalizedCourseCode: normalizedCourseCode,
  );
  if (entry == null) return;

  var replaced = false;
  final updatedSlots = entry.slots.map((slot) {
    if (slot.classSlotId == classSlotId) {
      replaced = true;
      return replacement.copyWith(classSlotId: slot.classSlotId);
    }
    return slot;
  }).toList(growable: false);

  if (!replaced) return;
  await upsertTimetableByCourse(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCourseCode,
    slots: updatedSlots,
  );
}

Future<void> deleteClassSlotSeries({
  required String sessionId,
  required String termId,
  required String courseCode,
  required String sourceDay,
  required int sourceStartMinutes,
  required int sourceEndMinutes,
}) async {
  final normalizedCourseCode = courseCode.trim().toUpperCase();
  final entry = _findTimetableEntryForCourse(
    sessionId: sessionId,
    termId: termId,
    normalizedCourseCode: normalizedCourseCode,
  );
  if (entry == null) return;

  final updatedSlots = <TimetableSlot>[];
  var removed = false;
  for (final slot in entry.slots) {
    final start = _parseMinutes12h(slot.startTime);
    final end = _parseMinutes12h(slot.endTime);
    final isTarget = slot.day.trim().toLowerCase() == sourceDay.trim().toLowerCase() &&
        start == sourceStartMinutes &&
        end == sourceEndMinutes;
    if (isTarget) {
      removed = true;
      continue;
    }
    updatedSlots.add(slot);
  }

  if (!removed) return;
  await upsertTimetableByCourse(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCourseCode,
    slots: updatedSlots,
  );
}

Future<void> deleteClassSlotSeriesById({
  required String sessionId,
  required String termId,
  required String courseCode,
  required String classSlotId,
}) async {
  final normalizedCourseCode = courseCode.trim().toUpperCase();
  final entry = _findTimetableEntryForCourse(
    sessionId: sessionId,
    termId: termId,
    normalizedCourseCode: normalizedCourseCode,
  );
  if (entry == null) return;

  final updatedSlots = <TimetableSlot>[];
  var removed = false;
  for (final slot in entry.slots) {
    if (slot.classSlotId == classSlotId) {
      removed = true;
      continue;
    }
    updatedSlots.add(slot);
  }

  if (!removed) return;
  await upsertTimetableByCourse(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCourseCode,
    slots: updatedSlots,
  );
}

class _EntryBuilder {
  _EntryBuilder({
    required this.id,
    required this.sessionId,
    required this.termId,
    this.courseId,
    required this.courseCode,
  });

  final String id;
  final String sessionId;
  final String termId;
  final String? courseId;
  final String courseCode;
  final List<TimetableSlot> slots = <TimetableSlot>[];

  void sortSlots() {
    slots.sort((a, b) {
      final dayCompare =
          weekdayOrderFromString(a.day).compareTo(weekdayOrderFromString(b.day));
      if (dayCompare != 0) return dayCompare;
      final aMinutes = _parseMinutes12h(a.startTime) ?? 0;
      final bMinutes = _parseMinutes12h(b.startTime) ?? 0;
      return aMinutes.compareTo(bMinutes);
    });
  }
}

class _SlotPayload {
  const _SlotPayload({
    required this.classSlotId,
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
    required this.mode,
    required this.classType,
    required this.venue,
  });

  final String classSlotId;
  final String day;
  final int startMinutes;
  final int endMinutes;
  final String mode;
  final ClassType classType;
  final String venue;

  String get exactKey =>
      '${day.toLowerCase()}|$startMinutes|$endMinutes|${mode.toLowerCase()}|${classType.name}|${venue.toLowerCase()}';

  String get sortKey =>
      '${weekdayOrderFromString(day).toString().padLeft(2, '0')}|${startMinutes.toString().padLeft(4, '0')}|${endMinutes.toString().padLeft(4, '0')}|${classType.name}|${mode.toLowerCase()}|${venue.toLowerCase()}';

  static _SlotPayload? fromTimetableSlot(TimetableSlot slot) {
    final startMinutes = _parseMinutes12h(slot.startTime);
    final endMinutes = _parseMinutes12h(slot.endTime);
    if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
      return null;
    }
    return _SlotPayload(
      classSlotId: slot.classSlotId.trim(),
      day: slot.day.trim(),
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      mode: slot.mode.trim(),
      classType: slot.classType,
      venue: (slot.venue ?? '').trim(),
    );
  }

  static _SlotPayload? fromFirestore(
    Map<String, dynamic> data, {
    required String fallbackClassSlotId,
  }) {
    final day = (data['day'] as String?)?.trim();
    final startMinutes = (data['startMinutes'] as num?)?.toInt();
    final endMinutes = (data['endMinutes'] as num?)?.toInt();
    final mode = (data['mode'] as String?)?.trim();
    final classTypeRaw = (data['classType'] as String?)?.trim().toLowerCase();
    if (day == null ||
        day.isEmpty ||
        startMinutes == null ||
        endMinutes == null ||
        mode == null ||
        mode.isEmpty ||
        endMinutes <= startMinutes) {
      return null;
    }
    return _SlotPayload(
      classSlotId: ((data['classSlotId'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['classSlotId'] as String).trim()
          : fallbackClassSlotId,
      day: day,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      mode: mode,
      classType: _parseClassType(classTypeRaw),
      venue: (data['venue'] as String?)?.trim() ?? '',
    );
  }
}

class _PersistedSlot {
  const _PersistedSlot({
    required this.doc,
    required this.payload,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final _SlotPayload? payload;

  static _PersistedSlot fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _PersistedSlot(
      doc: doc,
      payload: _SlotPayload.fromFirestore(
        doc.data(),
        fallbackClassSlotId: doc.id,
      ),
    );
  }
}
