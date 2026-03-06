import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/class_type.dart';
import '../models/timetable_entry.dart';
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
  final grouped = <String, _EntryBuilder>{};
  for (final doc in docs) {
    final data = doc.data();
    final sessionId = (data['sessionId'] as String?)?.trim() ?? '';
    final termId = (data['termId'] as String?)?.trim() ?? '';
    final courseCode = (data['courseCode'] as String?)?.trim().toUpperCase() ?? '';
    if (sessionId.isEmpty || termId.isEmpty || courseCode.isEmpty) continue;

    final key =
        (data['timetableScopedKey'] as String?)?.trim().isNotEmpty == true
        ? (data['timetableScopedKey'] as String).trim()
        : _buildScopedKey(
            sessionId: sessionId,
            termId: termId,
            courseCode: courseCode,
          );

    final slot = _slotFromMap(data);
    if (slot == null) continue;

    grouped.putIfAbsent(
      key,
      () => _EntryBuilder(
        id: key,
        sessionId: sessionId,
        termId: termId,
        courseCode: courseCode,
      ),
    );
    grouped[key]!.slots.add(slot);
  }

  final entries = grouped.values.map((builder) {
    builder.sortSlots();
    return TimetableEntry(
      id: builder.id,
      sessionId: builder.sessionId,
      termId: builder.termId,
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

TimetableSlot? _slotFromMap(Map<String, dynamic> data) {
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

int? _parseMinutes12h(String value) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  final hour12 = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  final period = (match.group(3) ?? '').toUpperCase();
  if (hour12 == null || minute == null) return null;
  if (hour12 < 1 || hour12 > 12 || minute < 0 || minute > 59) return null;
  final hour24 = period == 'AM' ? hour12 % 12 : (hour12 % 12) + 12;
  return (hour24 * 60) + minute;
}

String _formatMinutes12h(int minutes) {
  final normalized = ((minutes % 1440) + 1440) % 1440;
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minuteString = minute.toString().padLeft(2, '0');
  return '$hour12:$minuteString $period';
}

int _weekdayOrder(String day) {
  switch (day.toLowerCase()) {
    case 'monday':
      return 1;
    case 'tuesday':
      return 2;
    case 'wednesday':
      return 3;
    case 'thursday':
      return 4;
    case 'friday':
      return 5;
    case 'saturday':
      return 6;
    case 'sunday':
      return 7;
    default:
      return 99;
  }
}

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

  final existing = await _classSlotsCollection(user.uid)
      .where('timetableScopedKey', isEqualTo: scopedKey)
      .get();

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
  final newScopedKey = _buildScopedKey(
    sessionId: sessionId,
    termId: termId,
    courseCode: courseCode,
  );
  if (id != newScopedKey) {
    await deleteTimetableEntry(id);
  }
  await upsertTimetableByCourse(
    sessionId: sessionId,
    termId: termId,
    courseCode: courseCode,
    slots: slots,
  );
}

Map<String, dynamic> _slotWriteData({
  required String sessionId,
  required String termId,
  required String courseId,
  required String courseCode,
  required String scopedKey,
  required _SlotPayload slot,
  required bool includeCreatedAt,
}) {
  final data = <String, dynamic>{
    'sessionId': sessionId.trim(),
    'termId': termId.trim(),
    'courseId': courseId,
    'courseCode': courseCode,
    'timetableScopedKey': scopedKey,
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

  final snapshot = await _classSlotsCollection(user.uid)
      .where('timetableScopedKey', isEqualTo: id)
      .get();
  if (snapshot.docs.isEmpty) return;

  final batch = FirebaseFirestore.instance.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}

class _EntryBuilder {
  _EntryBuilder({
    required this.id,
    required this.sessionId,
    required this.termId,
    required this.courseCode,
  });

  final String id;
  final String sessionId;
  final String termId;
  final String courseCode;
  final List<TimetableSlot> slots = <TimetableSlot>[];

  void sortSlots() {
    slots.sort((a, b) {
      final dayCompare = _weekdayOrder(a.day).compareTo(_weekdayOrder(b.day));
      if (dayCompare != 0) return dayCompare;
      final aMinutes = _parseMinutes12h(a.startTime) ?? 0;
      final bMinutes = _parseMinutes12h(b.startTime) ?? 0;
      return aMinutes.compareTo(bMinutes);
    });
  }
}

class _SlotPayload {
  const _SlotPayload({
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
    required this.mode,
    required this.classType,
    required this.venue,
  });

  final String day;
  final int startMinutes;
  final int endMinutes;
  final String mode;
  final ClassType classType;
  final String venue;

  String get exactKey =>
      '${day.toLowerCase()}|$startMinutes|$endMinutes|${mode.toLowerCase()}|${classType.name}|${venue.toLowerCase()}';

  String get sortKey =>
      '${_weekdayOrder(day).toString().padLeft(2, '0')}|${startMinutes.toString().padLeft(4, '0')}|${endMinutes.toString().padLeft(4, '0')}|${classType.name}|${mode.toLowerCase()}|${venue.toLowerCase()}';

  static _SlotPayload? fromTimetableSlot(TimetableSlot slot) {
    final startMinutes = _parseMinutes12h(slot.startTime);
    final endMinutes = _parseMinutes12h(slot.endTime);
    if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
      return null;
    }
    return _SlotPayload(
      day: slot.day.trim(),
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      mode: slot.mode.trim(),
      classType: slot.classType,
      venue: (slot.venue ?? '').trim(),
    );
  }

  static _SlotPayload? fromFirestore(Map<String, dynamic> data) {
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
      payload: _SlotPayload.fromFirestore(doc.data()),
    );
  }
}
