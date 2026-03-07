import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/academic_session.dart';
import '../utils/term_windows.dart';

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 0, 0);

DateTime _endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59);

final ValueNotifier<AcademicSession?> currentAcademicSessionNotifier =
    ValueNotifier<AcademicSession?>(null);

final ValueNotifier<List<AcademicSession>> academicSessionsNotifier =
    ValueNotifier<List<AcademicSession>>([]);

// For backward compatibility
List<AcademicSession> get academicSessions => academicSessionsNotifier.value;

bool hasAcademicSession() => currentAcademicSessionNotifier.value != null;

StreamSubscription<User?>? _authSubscription;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionsSubscription;

CollectionReference<Map<String, dynamic>> _sessionsCollection(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection(
    'academicSessions',
  );
}

void initializeAcademicSessionsSync() {
  if (_authSubscription != null) return;

  _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
    _sessionsSubscription?.cancel();
    _sessionsSubscription = null;

    if (user == null) {
      academicSessionsNotifier.value = const <AcademicSession>[];
      currentAcademicSessionNotifier.value = null;
      return;
    }

    _sessionsSubscription = _sessionsCollection(user.uid)
        .orderBy('startDate')
        .snapshots()
        .listen((snapshot) {
          final sessions = snapshot.docs.map(_sessionFromDoc).toList(growable: false);
          academicSessionsNotifier.value = sessions;

          final currentDoc = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['isCurrent'] == true;
          });
          if (currentDoc.isNotEmpty) {
            currentAcademicSessionNotifier.value = _sessionFromDoc(currentDoc.first);
            return;
          }

          final previousId = currentAcademicSessionNotifier.value?.id;
          if (previousId != null) {
            final matched = sessions.where((s) => s.id == previousId);
            if (matched.isNotEmpty) {
              currentAcademicSessionNotifier.value = matched.first;
              return;
            }
          }

          currentAcademicSessionNotifier.value = sessions.isEmpty ? null : sessions.first;
        });
  });
}

AcademicSession _sessionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final name = (data['name'] as String?)?.trim();
  final startTs = data['startDate'] as Timestamp?;
  final endTs = data['endDate'] as Timestamp?;
  final fallback = AcademicSession.fromDates(
    startDate: DateTime.now(),
    endDate: DateTime.now(),
  );
  if (name == null || startTs == null || endTs == null) {
    return AcademicSession(
      id: doc.id,
      name: name ?? doc.id,
      startDate: startTs == null ? fallback.startDate : _startOfDay(startTs.toDate()),
      endDate: endTs == null ? fallback.endDate : _endOfDay(endTs.toDate()),
    );
  }
  return AcademicSession(
    id: doc.id,
    name: name,
    startDate: _startOfDay(startTs.toDate()),
    endDate: _endOfDay(endTs.toDate()),
  );
}

List<Map<String, dynamic>> _termArrayForSession(AcademicSession session) {
  return buildTermWindows(session)
      .map(
        (term) => <String, dynamic>{
          'id': term.id,
          'label': term.label,
          'startDate': Timestamp.fromDate(term.start),
          'endDate': Timestamp.fromDate(term.end),
        },
      )
      .toList(growable: false);
}

Future<void> setCurrentAcademicSession(AcademicSession session) async {
  currentAcademicSessionNotifier.value = session;
  final exists = academicSessionsNotifier.value.any((s) => s.id == session.id);
  if (!exists) {
    academicSessionsNotifier.value = [
      ...academicSessionsNotifier.value,
      session,
    ];
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final sessionsSnapshot = await _sessionsCollection(user.uid).get();
  final batch = FirebaseFirestore.instance.batch();
  for (final doc in sessionsSnapshot.docs) {
    batch.set(doc.reference, {
      'isCurrent': doc.id == session.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  await batch.commit();
}

Future<void> addAcademicSession(AcademicSession session) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final normalizedStart = _startOfDay(session.startDate);
  final normalizedEnd = _endOfDay(session.endDate);
  final normalizedSession = AcademicSession(
    id: session.id,
    name: session.name,
    startDate: normalizedStart,
    endDate: normalizedEnd,
  );
  final exists = academicSessionsNotifier.value.any(
    (s) =>
        s.name == session.name &&
        s.startDate == normalizedStart &&
        s.endDate == normalizedEnd,
  );
  if (exists) return;

  final isFirstSession = academicSessionsNotifier.value.isEmpty;
  await _sessionsCollection(user.uid).doc().set({
    'name': session.name,
    'startDate': Timestamp.fromDate(normalizedStart),
    'endDate': Timestamp.fromDate(normalizedEnd),
    'terms': _termArrayForSession(normalizedSession),
    'isCurrent': currentAcademicSessionNotifier.value == null || isFirstSession,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> updateAcademicSession(AcademicSession updatedSession) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final normalizedStart = _startOfDay(updatedSession.startDate);
  final normalizedEnd = _endOfDay(updatedSession.endDate);
  final normalizedSession = AcademicSession(
    id: updatedSession.id,
    name: updatedSession.name,
    startDate: normalizedStart,
    endDate: normalizedEnd,
  );
  final isCurrent = currentAcademicSessionNotifier.value?.id == updatedSession.id;
  await _sessionsCollection(user.uid).doc(updatedSession.id).set({
    'name': updatedSession.name,
    'startDate': Timestamp.fromDate(normalizedStart),
    'endDate': Timestamp.fromDate(normalizedEnd),
    'terms': _termArrayForSession(normalizedSession),
    'isCurrent': isCurrent,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> deleteAcademicSession(String sessionId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final deletingCurrent = currentAcademicSessionNotifier.value?.id == sessionId;
  await _sessionsCollection(user.uid).doc(sessionId).delete();

  if (deletingCurrent) {
    final remaining = await _sessionsCollection(user.uid)
        .orderBy('startDate')
        .limit(1)
        .get();
    if (remaining.docs.isNotEmpty) {
      await _sessionsCollection(user.uid).doc(remaining.docs.first.id).set({
        'isCurrent': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }
    currentAcademicSessionNotifier.value = null;
  }
}

