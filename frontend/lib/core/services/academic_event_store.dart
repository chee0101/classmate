import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/academic_event.dart';

final ValueNotifier<List<AcademicEvent>> academicEventsNotifier =
    ValueNotifier<List<AcademicEvent>>([]);

StreamSubscription<User?>? _eventAuthSubscription;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;

CollectionReference<Map<String, dynamic>> _eventsCollection(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection(
    'events',
  );
}

void initializeAcademicEventsSync() {
  if (_eventAuthSubscription != null) return;

  _eventAuthSubscription = FirebaseAuth.instance.authStateChanges().listen((
    user,
  ) {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;

    if (user == null) {
      academicEventsNotifier.value = const <AcademicEvent>[];
      return;
    }

    _eventsSubscription = _eventsCollection(user.uid)
        .orderBy('startDateTime')
        .snapshots()
        .listen((snapshot) {
          academicEventsNotifier.value = snapshot.docs
              .map(_eventFromDoc)
              .toList(growable: false);
        });
  });
}

bool _readBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

AcademicEvent _eventFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final startTimestamp = data['startDateTime'] as Timestamp?;
  final endTimestamp = data['endDateTime'] as Timestamp?;
  final now = DateTime.now();

  return AcademicEvent(
    id: doc.id,
    sessionId: (data['sessionId'] as String?)?.trim() ?? '',
    termId: (data['termId'] as String?)?.trim() ?? '',
    title: ((data['title'] as String?) ?? '').trim(),
    startDateTime: startTimestamp?.toDate() ?? now,
    endDateTime: endTimestamp?.toDate() ?? now,
    allDay: _readBool(data['allDay']),
    hideClassesDuringEvent: (data['hideClassesDuringEvent'] as bool?) ?? true,
    isAcademicBreak: (data['isAcademicBreak'] as bool?) ?? false,
    location: (data['location'] as String?)?.trim(),
  );
}

String _compactDateKey(DateTime dt) {
  final y = (dt.year % 100).toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

String _safeToken(String input) {
  final normalized = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final trimmed = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  if (trimmed.isEmpty) return 'na';
  return trimmed.length <= 12 ? trimmed : trimmed.substring(0, 12);
}

String _shortHash(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0').substring(0, 6);
}

/// Shared ID builder used by both auto-extract and manual paths.
String buildAcademicEventDocId(AcademicEvent event) {
  final provided = event.id.trim();
  if (provided.isNotEmpty) return provided;

  if (event.isAcademicBreak) {
    final sid = _safeToken(event.sessionId);
    final term = _safeToken(event.termId);
    final date = _compactDateKey(event.startDateTime);
    final titleHash = _shortHash(event.title.trim());
    return 'acb_${sid}_${term}_${date}_$titleHash';
  }

  return 'ev_${DateTime.now().microsecondsSinceEpoch}';
}

Future<String?> addAcademicEvent(AcademicEvent event) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final docRef = _eventsCollection(user.uid).doc(buildAcademicEventDocId(event));
  await docRef.set({
    'sessionId': event.sessionId.trim(),
    'termId': event.termId.trim(),
    'title': event.title.trim(),
    'startDateTime': Timestamp.fromDate(event.startDateTime),
    'endDateTime': Timestamp.fromDate(event.endDateTime),
    'allDay': event.allDay,
    'hideClassesDuringEvent': event.hideClassesDuringEvent,
    'isAcademicBreak': event.isAcademicBreak,
    'location': (event.location ?? '').trim().isEmpty
        ? null
        : (event.location ?? '').trim(),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  return docRef.id;
}

Future<void> updateAcademicEvent(AcademicEvent event) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await _eventsCollection(user.uid).doc(event.id).set({
    'sessionId': event.sessionId.trim(),
    'termId': event.termId.trim(),
    'title': event.title.trim(),
    'startDateTime': Timestamp.fromDate(event.startDateTime),
    'endDateTime': Timestamp.fromDate(event.endDateTime),
    'allDay': event.allDay,
    'hideClassesDuringEvent': event.hideClassesDuringEvent,
    'isAcademicBreak': event.isAcademicBreak,
    'location': (event.location ?? '').trim().isEmpty
        ? null
        : (event.location ?? '').trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> deleteAcademicEvent(String eventId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  await _eventsCollection(user.uid).doc(eventId).delete();
}

