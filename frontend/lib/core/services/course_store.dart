import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../utils/course_resolver.dart';
import 'cascade_cleanup.dart';

final ValueNotifier<List<Course>> coursesNotifier = ValueNotifier<List<Course>>(
  [],
);

StreamSubscription<User?>? _authSubscription;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _coursesSubscription;

CollectionReference<Map<String, dynamic>> _coursesCollection(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection(
    'courses',
  );
}

/// Resolves a course doc id by [sessionId], [termId], and normalized [courseCode].
/// Uses cache first, then a single `sessionId` query and filters in memory (avoids extra composite fields).
Future<String?> findCourseIdBySessionTermCode({
  required String uid,
  required String sessionId,
  required String termId,
  required String normalizedCourseCode,
}) async {
  final cached = resolveCourseIdByCodeInSessionAndTerm(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCourseCode,
  );
  if (cached != null) return cached;

  final snapshot =
      await _coursesCollection(uid).where('sessionId', isEqualTo: sessionId).get();
  for (final doc in snapshot.docs) {
    final d = doc.data();
    if ((d['termId'] as String?)?.trim() == termId.trim() &&
        (d['courseCode'] as String?)?.trim().toUpperCase() ==
            normalizedCourseCode) {
      return doc.id;
    }
  }
  return null;
}

Course _courseFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Course(
    id: doc.id,
    sessionId: (data['sessionId'] as String?)?.trim() ?? '',
    termId: (data['termId'] as String?)?.trim() ?? '',
    courseCode: (data['courseCode'] as String?)?.trim().toUpperCase() ?? '',
    courseColor: (data['courseColor'] as String?)?.trim() ?? '#3B82F6',
  );
}

void initializeCoursesSync() {
  if (_authSubscription != null) return;

  _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
    _coursesSubscription?.cancel();
    _coursesSubscription = null;

    if (user == null) {
      coursesNotifier.value = const <Course>[];
      return;
    }

    _coursesSubscription = _coursesCollection(user.uid)
        .orderBy('courseCode')
        .snapshots()
        .listen((snapshot) {
          coursesNotifier.value = snapshot.docs.map(_courseFromDoc).toList(
            growable: false,
          );
        });
  });
}

List<Course> coursesForSession(String sessionId) {
  return coursesNotifier.value
      .where((c) => c.sessionId == sessionId)
      .toList(growable: false);
}

List<Course> coursesForSessionAndTerm({
  required String sessionId,
  required String termId,
}) {
  return coursesNotifier.value
      .where((c) => c.sessionId == sessionId && c.termId == termId)
      .toList(growable: false);
}

List<String> courseCodesForSessionAndTerm({
  required String sessionId,
  required String termId,
  String? includeCode,
}) {
  final set = coursesForSessionAndTerm(sessionId: sessionId, termId: termId)
      .map((c) => c.courseCode.trim().toUpperCase())
      .where((c) => c.isNotEmpty)
      .toSet();
  final normalizedInclude = includeCode?.trim().toUpperCase();
  if (normalizedInclude != null && normalizedInclude.isNotEmpty) {
    set.add(normalizedInclude);
  }
  final list = set.toList(growable: false)..sort();
  return list;
}

/// Canonical [Course] row for the current user cache; null if unknown or missing.
Course? courseByIdFromNotifier(String courseId) {
  return lookupCourseById(courseId, coursesNotifier.value);
}

String? resolveCourseIdByCodeInSessionAndTerm({
  required String sessionId,
  required String termId,
  required String courseCode,
}) {
  final normalized = courseCode.trim().toUpperCase();
  final matched = coursesNotifier.value.where(
    (c) =>
        c.sessionId == sessionId &&
        c.termId == termId &&
        c.courseCode.toUpperCase() == normalized,
  );
  return matched.isEmpty ? null : matched.first.id;
}

({String sessionId, String termId})? courseScopeForCourseId(String courseId) {
  final matched = coursesNotifier.value.where((c) => c.id == courseId);
  if (matched.isEmpty) return null;
  final course = matched.first;
  if (course.sessionId.trim().isEmpty || course.termId.trim().isEmpty) {
    return null;
  }
  return (sessionId: course.sessionId, termId: course.termId);
}

bool hasCoursesForSession(String sessionId) {
  return coursesNotifier.value.any((c) => c.sessionId == sessionId);
}

bool courseCodeExistsInSession({
  required String sessionId,
  required String courseCode,
}) {
  final normalized = courseCode.trim().toUpperCase();
  return coursesNotifier.value.any(
    (c) => c.sessionId == sessionId && c.courseCode.toUpperCase() == normalized,
  );
}

bool courseCodeExistsInSessionAndTerm({
  required String sessionId,
  required String termId,
  required String courseCode,
}) {
  return resolveCourseIdByCodeInSessionAndTerm(
        sessionId: sessionId,
        termId: termId,
        courseCode: courseCode,
      ) !=
      null;
}

bool courseCodeExistsInSessionAndTermExcludingCourse({
  required String sessionId,
  required String termId,
  required String courseId,
  required String courseCode,
}) {
  final normalized = courseCode.trim().toUpperCase();
  return coursesNotifier.value.any(
    (c) =>
        c.id != courseId &&
        c.sessionId == sessionId &&
        c.termId == termId &&
        c.courseCode.toUpperCase() == normalized,
  );
}

Future<void> addCourse({
  required String sessionId,
  required String termId,
  required String courseCode,
  required String courseColor,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final normalizedCode = courseCode.trim().toUpperCase();
  final existingId = await findCourseIdBySessionTermCode(
    uid: user.uid,
    sessionId: sessionId,
    termId: termId,
    normalizedCourseCode: normalizedCode,
  );
  if (existingId != null) {
    return;
  }

  final docRef = _coursesCollection(user.uid).doc();
  await docRef.set({
    'sessionId': sessionId,
    'termId': termId,
    'courseCode': normalizedCode,
    'courseColor': courseColor,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> updateCourse({
  required String id,
  required String sessionId,
  required String termId,
  required String courseCode,
  required String courseColor,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final normalizedCode = courseCode.trim().toUpperCase();
  final conflictId = await findCourseIdBySessionTermCode(
    uid: user.uid,
    sessionId: sessionId,
    termId: termId,
    normalizedCourseCode: normalizedCode,
  );
  if (conflictId != null && conflictId != id) {
    return;
  }

  await _coursesCollection(user.uid).doc(id).set({
    'sessionId': sessionId,
    'termId': termId,
    'courseCode': normalizedCode,
    'courseColor': courseColor,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> deleteCourse(String id) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await CascadeCleanup.deleteCourseDependents(user.uid, id);
  await _coursesCollection(user.uid).doc(id).delete();
}
