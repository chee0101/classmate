import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/task.dart';
import 'course_store.dart';

final ValueNotifier<List<Task>> tasksNotifier = ValueNotifier<List<Task>>([]);

StreamSubscription<User?>? _taskAuthSubscription;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSubscription;

CollectionReference<Map<String, dynamic>> _tasksCollection(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection(
    'tasks',
  );
}

void initializeTasksSync() {
  if (_taskAuthSubscription != null) return;

  _taskAuthSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
    _tasksSubscription?.cancel();
    _tasksSubscription = null;

    if (user == null) {
      tasksNotifier.value = const <Task>[];
      return;
    }

    _tasksSubscription = _tasksCollection(user.uid)
        .orderBy('dueDateTime')
        .snapshots()
        .listen((snapshot) {
          final tasks = snapshot.docs.map(_taskFromDoc).toList(growable: false);
          tasksNotifier.value = tasks;
        });
  });
}

Task _taskFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final rawCourseId = (data['courseId'] as String?)?.trim();
  final dueTimestamp = data['dueDateTime'] as Timestamp?;
  final statusRaw = (data['status'] as String?) ?? 'ongoing';
  final colorHex = (data['courseColor'] as String?) ?? '#6C4DD9';
  final colorValue = int.tryParse(colorHex.replaceFirst('#', '0xFF'));

  return Task(
    id: doc.id,
    courseId: (rawCourseId == null || rawCourseId.isEmpty) ? null : rawCourseId,
    courseCode: ((data['courseCode'] as String?) ?? '').trim().toUpperCase(),
    courseColor: Color(colorValue ?? 0xFF6C4DD9),
    title: ((data['title'] as String?) ?? '').trim(),
    description: (data['description'] as String?)?.trim(),
    dueDateTime: dueTimestamp?.toDate() ?? DateTime.now(),
    status: _statusFromString(statusRaw),
    parentTaskId: data['parentTaskId'] as String?,
  );
}

TaskStatus _statusFromString(String value) {
  switch (value.toLowerCase()) {
    case 'completed':
      return TaskStatus.completed;
    case 'overdue':
      return TaskStatus.overdue;
    case 'ongoing':
    default:
      return TaskStatus.ongoing;
  }
}

String _statusToString(TaskStatus status) {
  switch (status) {
    case TaskStatus.completed:
      return 'completed';
    case TaskStatus.overdue:
      return 'overdue';
    case TaskStatus.ongoing:
      return 'ongoing';
  }
}

String _toHexColor(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

String? _resolveCourseIdFromTask(Task task) {
  if (task.courseId != null && task.courseId!.trim().isNotEmpty) {
    return task.courseId!.trim();
  }
  final normalizedCode = task.courseCode.trim().toUpperCase();
  if (normalizedCode.isEmpty) return null;
  final matchedCourse = coursesNotifier.value.where((course) {
    return course.courseCode.toUpperCase() == normalizedCode;
  });
  return matchedCourse.isEmpty ? null : matchedCourse.first.id;
}

Future<String?> addTask(Task task) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final docRef = _tasksCollection(user.uid).doc();
  final resolvedCourseId = _resolveCourseIdFromTask(task);
  await docRef.set({
    'courseId': resolvedCourseId,
    'courseCode': task.courseCode.trim().toUpperCase(),
    'courseColor': _toHexColor(task.courseColor),
    'title': task.title.trim(),
    'description': task.description?.trim(),
    'dueDateTime': Timestamp.fromDate(task.dueDateTime),
    'status': _statusToString(task.status),
    'parentTaskId': task.parentTaskId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  return docRef.id;
}

Future<void> updateTask(Task task) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final resolvedCourseId = _resolveCourseIdFromTask(task);
  await _tasksCollection(user.uid).doc(task.id).set({
    'courseId': resolvedCourseId,
    'courseCode': task.courseCode.trim().toUpperCase(),
    'courseColor': _toHexColor(task.courseColor),
    'title': task.title.trim(),
    'description': task.description?.trim(),
    'dueDateTime': Timestamp.fromDate(task.dueDateTime),
    'status': _statusToString(task.status),
    'parentTaskId': task.parentTaskId,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> deleteTask(
  String taskId, {
  bool deleteSubtasks = false,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  if (!deleteSubtasks) {
    await _tasksCollection(user.uid).doc(taskId).delete();
    return;
  }

  final batch = FirebaseFirestore.instance.batch();
  final parentRef = _tasksCollection(user.uid).doc(taskId);
  batch.delete(parentRef);

  final subtasks = await _tasksCollection(user.uid)
      .where('parentTaskId', isEqualTo: taskId)
      .get();
  for (final subtaskDoc in subtasks.docs) {
    batch.delete(subtaskDoc.reference);
  }
  await batch.commit();
}

List<Task> subtasksForParent(String parentTaskId) {
  return tasksNotifier.value
      .where((task) => task.parentTaskId == parentTaskId)
      .toList(growable: false);
}
