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
    allDay: (data['allDay'] as bool?) ?? false,
    hideClassesDuringEvent: (data['hideClassesDuringEvent'] as bool?) ?? true,
    isAcademicBreak: (data['isAcademicBreak'] as bool?) ?? false,
    location: (data['location'] as String?)?.trim(),
  );
}

Future<String?> addAcademicEvent(AcademicEvent event) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final docRef = _eventsCollection(user.uid).doc();
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

