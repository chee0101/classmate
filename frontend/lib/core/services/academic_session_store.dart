import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/academic_session.dart';
import '../models/academic_event.dart';
import 'session_term_selection_store.dart';
import '../utils/term_windows.dart';
import 'cascade_cleanup.dart';
import 'course_store.dart';

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 0, 0);

DateTime _endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59);

DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
  if (value.isBefore(min)) return min;
  if (value.isAfter(max)) return max;
  return value;
}

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
      clearSelectedSessionTerm();
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
      terms: const <SessionTerm>[],
    );
  }
  final startDate = _startOfDay(startTs.toDate());
  final endDate = _endOfDay(endTs.toDate());
  return AcademicSession(
    id: doc.id,
    name: name,
    startDate: startDate,
    endDate: endDate,
    terms: _readTermsFromDoc(data['terms'], sessionStart: startDate, sessionEnd: endDate),
  );
}

List<SessionTerm> _readTermsFromDoc(
  dynamic raw, {
  required DateTime sessionStart,
  required DateTime sessionEnd,
}) {
  if (raw is! List) return const <SessionTerm>[];
  final out = <SessionTerm>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final id = (map['id'] as String?)?.trim() ?? '';
    final label = (map['label'] as String?)?.trim() ?? '';
    final startTs = map['startDate'] as Timestamp?;
    final endTs = map['endDate'] as Timestamp?;
    if (id.isEmpty || label.isEmpty || startTs == null || endTs == null) {
      continue;
    }
    final start = _clampDate(
      _startOfDay(startTs.toDate()),
      sessionStart,
      sessionEnd,
    );
    final end = _clampDate(
      _endOfDay(endTs.toDate()),
      sessionStart,
      sessionEnd,
    );
    if (end.isBefore(start)) continue;
    out.add(SessionTerm(id: id, label: label, start: start, end: end));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
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
    terms: session.terms
        .map(
          (term) => SessionTerm(
            id: term.id.trim(),
            label: term.label.trim(),
            start: _clampDate(
              _startOfDay(term.start),
              normalizedStart,
              normalizedEnd,
            ),
            end: _clampDate(
              _endOfDay(term.end),
              normalizedStart,
              normalizedEnd,
            ),
          ),
        )
        .where((term) => term.id.isNotEmpty && term.label.isNotEmpty)
        .toList(growable: false),
  );
  final exists = academicSessionsNotifier.value.any(
    (s) =>
        s.name == session.name &&
        s.startDate == normalizedStart &&
        s.endDate == normalizedEnd,
  );
  if (exists) return;

  final isFirstSession = academicSessionsNotifier.value.isEmpty;
  // Use the provided client-side id as the Firestore document id so that
  // `AcademicSession.id` stays consistent across screens and when seeding events.
  await _sessionsCollection(user.uid).doc(session.id).set({
    'name': session.name,
    'startDate': Timestamp.fromDate(normalizedStart),
    'endDate': Timestamp.fromDate(normalizedEnd),
    'terms': _termArrayForSession(normalizedSession),
    'isCurrent': currentAcademicSessionNotifier.value == null || isFirstSession,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  await _seedAcademicBreakEventsForSession(
    userUid: user.uid,
    session: normalizedSession,
  );
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
    terms: updatedSession.terms
        .map(
          (term) => SessionTerm(
            id: term.id.trim(),
            label: term.label.trim(),
            start: _clampDate(
              _startOfDay(term.start),
              normalizedStart,
              normalizedEnd,
            ),
            end: _clampDate(
              _endOfDay(term.end),
              normalizedStart,
              normalizedEnd,
            ),
          ),
        )
        .where((term) => term.id.isNotEmpty && term.label.isNotEmpty)
        .toList(growable: false),
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

  await _seedAcademicBreakEventsForSession(
    userUid: user.uid,
    session: normalizedSession,
  );
}

DateTime _clampToTerm(DateTime value, DateTime termStart, DateTime termEnd) {
  if (value.isBefore(termStart)) return termStart;
  if (value.isAfter(termEnd)) return termEnd;
  return value;
}

class _SeededAcademicBreak {
  const _SeededAcademicBreak({
    required this.title,
    required this.weekStart,
    required this.weekLength,
  });

  final String title;
  final int weekStart; // 1-based week within the term
  final int weekLength; // in weeks; use a large value + clamp for remainder
}

List<_SeededAcademicBreak> _academicBreaksForTerm(TermWindow term) {
  // Semester 1 pattern:
  // 1-7: T&L, 8: Mid-sem break, 9-15: T&L, 16: Revision, 17-19: Exam, 20-23: Mid-sem break (4 weeks)
  // Semester 2 pattern:
  // 1-7: T&L, 8: Mid-sem break, 9-15: T&L, 16: Revision, 17-19: Exam, 20+: Long break
  final isSem1 = term.id == 'sem1' || term.label.toLowerCase().contains('semester 1');

  if (isSem1) {
    return const [
      _SeededAcademicBreak(title: 'Mid-Semester Break', weekStart: 8, weekLength: 1),
      _SeededAcademicBreak(title: 'Revision Week', weekStart: 16, weekLength: 1),
      _SeededAcademicBreak(title: 'Exam Week', weekStart: 17, weekLength: 3),
      _SeededAcademicBreak(title: 'Mid-Semester Break', weekStart: 20, weekLength: 4),
    ];
  }

  final isSem2 = term.id == 'sem2' || term.label.toLowerCase().contains('semester 2');
  if (isSem2) {
    return const [
      _SeededAcademicBreak(title: 'Mid-Semester Break', weekStart: 8, weekLength: 1),
      _SeededAcademicBreak(title: 'Revision Week', weekStart: 16, weekLength: 1),
      _SeededAcademicBreak(title: 'Exam Week', weekStart: 17, weekLength: 3),
      // weekLength is clamped to term.end inside the seeding function.
      _SeededAcademicBreak(title: 'Long Break', weekStart: 20, weekLength: 999),
    ];
  }

  return const [];
}

bool _intervalsOverlap(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  return !aEnd.isBefore(bStart) && !aStart.isAfter(bEnd);
}

Future<void> _seedAcademicBreakEventsForSession({
  required String userUid,
  required AcademicSession session,
}) async {
  final eventCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(userUid)
      .collection('events');

  final terms = buildTermWindows(session);

  // Fetch existing events for this session so we can update/migrate older docs
  // that might exist without `isAcademicBreak`.
  final existingSnap =
      await eventCollection.where('sessionId', isEqualTo: session.id).get();
  final existingDocs = existingSnap.docs;

  final seeded = <AcademicEvent>[];
  for (final term in terms) {
    final breaks = _academicBreaksForTerm(term);
    for (final b in breaks) {
      final startCandidate = term.start.add(Duration(days: (b.weekStart - 1) * 7));
      // The above formula can be hard to reason about; compute as:
      // start = weekStart-1 weeks from term start
      // end = start + weekLength weeks - 1 day
      final startDay = DateTime(
        startCandidate.year,
        startCandidate.month,
        startCandidate.day,
        0,
        0,
      );
      final endDayRaw = startCandidate.add(Duration(days: b.weekLength * 7 - 1));
      final start = startDay.isBefore(term.start) ? term.start : _startOfDay(startDay);
      final end = _clampToTerm(_endOfDay(endDayRaw), term.start, term.end);

      if (end.isBefore(start)) continue;

      seeded.add(
        AcademicEvent(
          id: '',
          sessionId: session.id,
          termId: term.id,
          title: b.title,
          startDateTime: start,
          endDateTime: end,
          allDay: true,
          hideClassesDuringEvent: false,
          isAcademicBreak: true,
          location: null,
        ),
      );
    }
  }

  // Upsert/migrate: try to match existing events by sessionId+termId+title
  // and overlap with the seeded range. Prefer ones already marked as academic break.
  final batch = FirebaseFirestore.instance.batch();
  for (final breakEvent in seeded) {
    final matches = existingDocs.where((doc) {
      final data = doc.data();
      if ((data['termId'] as String?)?.trim() != breakEvent.termId) return false;
      if ((data['title'] as String?)?.trim() != breakEvent.title) return false;
      final startTs = data['startDateTime'] as Timestamp?;
      final endTs = data['endDateTime'] as Timestamp?;
      if (startTs == null || endTs == null) return false;
      final start = startTs.toDate();
      final end = endTs.toDate();
      return _intervalsOverlap(start, end, breakEvent.startDateTime, breakEvent.endDateTime);
    }).toList(growable: false);

    // Choose:
    // 1) any already-flagged academic break event, otherwise
    // 2) the first overlap match to migrate.
    QueryDocumentSnapshot<Map<String, dynamic>>? selectedMatch;
    for (final doc in matches) {
      if ((doc.data()['isAcademicBreak'] as bool?) == true) {
        selectedMatch = doc;
        break;
      }
    }
    selectedMatch ??= matches.isNotEmpty ? matches.first : null;

    final updatePayload = {
      'sessionId': breakEvent.sessionId,
      'termId': breakEvent.termId,
      'title': breakEvent.title,
      'startDateTime': Timestamp.fromDate(breakEvent.startDateTime),
      'endDateTime': Timestamp.fromDate(breakEvent.endDateTime),
      'allDay': breakEvent.allDay,
      'hideClassesDuringEvent': breakEvent.hideClassesDuringEvent,
      'isAcademicBreak': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (selectedMatch != null) {
      batch.set(
        selectedMatch.reference,
        updatePayload,
        SetOptions(merge: true),
      );
      continue;
    }

    final safeStartKey =
        '${breakEvent.startDateTime.year}-${breakEvent.startDateTime.month.toString().padLeft(2, '0')}-${breakEvent.startDateTime.day.toString().padLeft(2, '0')}';
    final docId =
        'academic_break_${breakEvent.termId}_${breakEvent.title.replaceAll(RegExp(r'\\s+'), '_').toLowerCase()}_$safeStartKey';
    batch.set(
      eventCollection.doc(docId),
      {
        ...updatePayload,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  await batch.commit();
}

Future<void> deleteAcademicSession(String sessionId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final coursesSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('courses')
      .where('sessionId', isEqualTo: sessionId)
      .get();
  for (final doc in coursesSnap.docs) {
    await deleteCourse(doc.id);
  }

  await CascadeCleanup.deleteEventsForSessionId(user.uid, sessionId);
  await CascadeCleanup.deleteClassSlotsForSessionId(user.uid, sessionId);

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

