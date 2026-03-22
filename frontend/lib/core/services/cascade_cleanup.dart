import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized deletes for related data so parent removal does not leave orphans.
/// Uses [courseId], [sessionId], and Firestore [doc.id] for class slots (no duplicate id fields).
class CascadeCleanup {
  CascadeCleanup._();

  static CollectionReference<Map<String, dynamic>> _classSlots(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('classSlots');
  }

  static CollectionReference<Map<String, dynamic>> _tasks(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks');
  }

  static CollectionReference<Map<String, dynamic>> _overrides(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('classSlotOverrides');
  }

  static CollectionReference<Map<String, dynamic>> _events(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('events');
  }

  /// Deletes overrides that reference any of the given class-slot **document** ids.
  static Future<void> deleteOverridesForClassSlotDocIds(
    String uid,
    List<String> slotDocIds,
  ) async {
    if (slotDocIds.isEmpty) return;
    final col = _overrides(uid);
    for (final slotId in slotDocIds) {
      final snap = await col.where('classSlotId', isEqualTo: slotId).get();
      if (snap.docs.isEmpty) continue;
      await _batchDeleteDocRefs(snap.docs.map((d) => d.reference).toList());
    }
  }

  static Future<void> _batchDeleteDocRefs(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    if (refs.isEmpty) return;
    const chunkSize = 450;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      final end = math.min(i + chunkSize, refs.length);
      for (var j = i; j < end; j++) {
        batch.delete(refs[j]);
      }
      await batch.commit();
    }
  }

  static Future<void> _batchDeleteQueryDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;
    await _batchDeleteDocRefs(docs.map((d) => d.reference).toList());
  }

  /// Deletes all documents in [snapshot] in chunks (Firestore batch limit).
  static Future<void> deleteQuerySnapshotDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    await _batchDeleteQueryDocs(snapshot.docs);
  }

  /// All tasks whose [courseId] matches (including subtasks that share the same course).
  static Future<void> deleteTasksForCourseId(String uid, String courseId) async {
    final snap = await _tasks(uid).where('courseId', isEqualTo: courseId).get();
    await _batchDeleteQueryDocs(snap.docs);
  }

  /// All class slot documents for a course; overrides removed first.
  static Future<void> deleteClassSlotsForCourseId(String uid, String courseId) async {
    final snap = await _classSlots(uid).where('courseId', isEqualTo: courseId).get();
    if (snap.docs.isEmpty) return;
    final ids = snap.docs.map((d) => d.id).toList(growable: false);
    await deleteOverridesForClassSlotDocIds(uid, ids);
    await _batchDeleteQueryDocs(snap.docs);
  }

  /// Events tied to an academic session.
  static Future<void> deleteEventsForSessionId(String uid, String sessionId) async {
    final snap = await _events(uid).where('sessionId', isEqualTo: sessionId).get();
    await _batchDeleteQueryDocs(snap.docs);
  }

  /// Orphan class slots that still reference a session (e.g. legacy rows).
  static Future<void> deleteClassSlotsForSessionId(String uid, String sessionId) async {
    final snap =
        await _classSlots(uid).where('sessionId', isEqualTo: sessionId).get();
    if (snap.docs.isEmpty) return;
    final ids = snap.docs.map((d) => d.id).toList(growable: false);
    await deleteOverridesForClassSlotDocIds(uid, ids);
    await _batchDeleteQueryDocs(snap.docs);
  }

  /// Tasks + class slots (+ overrides) for a course. Does **not** delete the course doc.
  static Future<void> deleteCourseDependents(String uid, String courseId) async {
    await deleteClassSlotsForCourseId(uid, courseId);
    await deleteTasksForCourseId(uid, courseId);
  }

}
