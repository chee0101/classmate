import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/academic_session.dart';
import '../utils/term_windows.dart';

final ValueNotifier<AcademicSession?> currentAcademicSessionNotifier =
    ValueNotifier<AcademicSession?>(null);

final ValueNotifier<List<AcademicSession>> mockAcademicSessionsNotifier =
    ValueNotifier<List<AcademicSession>>([]);

// For backward compatibility
List<AcademicSession> get mockAcademicSessions => mockAcademicSessionsNotifier.value;

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
      mockAcademicSessionsNotifier.value = const <AcademicSession>[];
      currentAcademicSessionNotifier.value = null;
      return;
    }

    _sessionsSubscription = _sessionsCollection(user.uid)
        .orderBy('startDate')
        .snapshots()
        .listen((snapshot) {
          final sessions = snapshot.docs.map(_sessionFromDoc).toList(growable: false);
          mockAcademicSessionsNotifier.value = sessions;

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
      startDate: startTs?.toDate() ?? fallback.startDate,
      endDate: endTs?.toDate() ?? fallback.endDate,
    );
  }
  return AcademicSession(
    id: doc.id,
    name: name,
    startDate: startTs.toDate(),
    endDate: endTs.toDate(),
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
  final exists = mockAcademicSessionsNotifier.value.any((s) => s.id == session.id);
  if (!exists) {
    mockAcademicSessionsNotifier.value = [
      ...mockAcademicSessionsNotifier.value,
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

  final exists = mockAcademicSessionsNotifier.value.any(
    (s) =>
        s.name == session.name &&
        s.startDate == session.startDate &&
        s.endDate == session.endDate,
  );
  if (exists) return;

  final isFirstSession = mockAcademicSessionsNotifier.value.isEmpty;
  await _sessionsCollection(user.uid).doc().set({
    'name': session.name,
    'startDate': Timestamp.fromDate(session.startDate),
    'endDate': Timestamp.fromDate(session.endDate),
    'terms': _termArrayForSession(session),
    'isCurrent': currentAcademicSessionNotifier.value == null || isFirstSession,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> updateAcademicSession(AcademicSession updatedSession) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final isCurrent = currentAcademicSessionNotifier.value?.id == updatedSession.id;
  await _sessionsCollection(user.uid).doc(updatedSession.id).set({
    'name': updatedSession.name,
    'startDate': Timestamp.fromDate(updatedSession.startDate),
    'endDate': Timestamp.fromDate(updatedSession.endDate),
    'terms': _termArrayForSession(updatedSession),
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
