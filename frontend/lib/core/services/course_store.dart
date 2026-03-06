import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/course.dart';

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

String _buildCourseScopedKey({
  required String sessionId,
  required String termId,
  required String courseCode,
}) {
  return '${sessionId.trim()}::${termId.trim()}::${courseCode.trim().toUpperCase()}';
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
  final normalized = courseCode.trim().toUpperCase();
  return coursesNotifier.value.any(
    (c) =>
        c.sessionId == sessionId &&
        c.termId == termId &&
        c.courseCode.toUpperCase() == normalized,
  );
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
  final scopedKey = _buildCourseScopedKey(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCode,
  );

  final existsSnapshot = await _coursesCollection(user.uid)
      .where('courseScopedKey', isEqualTo: scopedKey)
      .limit(1)
      .get();
  if (existsSnapshot.docs.isNotEmpty) {
    return;
  }

  final docRef = _coursesCollection(user.uid).doc();
  await docRef.set({
    'sessionId': sessionId,
    'termId': termId,
    'courseCode': normalizedCode,
    'courseCodeNormalized': normalizedCode,
    'courseScopedKey': scopedKey,
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
  final scopedKey = _buildCourseScopedKey(
    sessionId: sessionId,
    termId: termId,
    courseCode: normalizedCode,
  );

  final duplicateSnapshot = await _coursesCollection(user.uid)
      .where('courseScopedKey', isEqualTo: scopedKey)
      .limit(2)
      .get();
  final exists = duplicateSnapshot.docs.any((doc) => doc.id != id);

  if (exists) {
    return;
  }

  await _coursesCollection(user.uid).doc(id).set({
    'sessionId': sessionId,
    'termId': termId,
    'courseCode': normalizedCode,
    'courseCodeNormalized': normalizedCode,
    'courseScopedKey': scopedKey,
    'courseColor': courseColor,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> deleteCourse(String id) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await _coursesCollection(user.uid).doc(id).delete();
}
