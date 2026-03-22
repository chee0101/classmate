import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/task.dart';
import 'course_store.dart';

final ValueNotifier<List<Task>> tasksNotifier = ValueNotifier<List<Task>>([]);

StreamSubscription<User?>? _taskAuthSubscription;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSubscription;

/// Last task document snapshots; used to re-map [Task]s when [coursesNotifier] updates
/// (course code/color come from [Course] when the task doc only stores [courseId]).
List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedTaskDocs = const [];

CollectionReference<Map<String, dynamic>> _tasksCollection(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection(
    'tasks',
  );
}

void _rebuildTasksFromCourseCache() {
  if (_cachedTaskDocs.isEmpty) return;
  tasksNotifier.value =
      _cachedTaskDocs.map(_taskFromDoc).toList(growable: false);
}

void initializeTasksSync() {
  if (_taskAuthSubscription != null) return;

  _taskAuthSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
    _tasksSubscription?.cancel();
    _tasksSubscription = null;
    coursesNotifier.removeListener(_rebuildTasksFromCourseCache);

    if (user == null) {
      _cachedTaskDocs = const [];
      tasksNotifier.value = const <Task>[];
      return;
    }

    coursesNotifier.addListener(_rebuildTasksFromCourseCache);

    _tasksSubscription = _tasksCollection(user.uid)
        .orderBy('dueDateTime')
        .snapshots()
        .listen((snapshot) {
          _cachedTaskDocs = snapshot.docs;
          final tasks = snapshot.docs.map(_taskFromDoc).toList(growable: false);
          tasksNotifier.value = tasks;
        });
  });
}

Color _colorFromHex(String? hex) {
  final value = int.tryParse((hex ?? '#6C4DD9').replaceFirst('#', '0xFF'));
  return Color(value ?? 0xFF6C4DD9);
}

Course? _courseById(String courseId) {
  for (final c in coursesNotifier.value) {
    if (c.id == courseId) return c;
  }
  return null;
}

Task _taskFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final rawCourseId = (data['courseId'] as String?)?.trim();
  final dueTimestamp = data['dueDateTime'] as Timestamp?;
  final statusRaw = (data['status'] as String?) ?? 'ongoing';
  final storedCode = ((data['courseCode'] as String?) ?? '').trim().toUpperCase();
  final storedColorHex = (data['courseColor'] as String?) ?? '#6C4DD9';

  String courseCode = storedCode;
  Color courseColor = _colorFromHex(storedColorHex);

  if (rawCourseId != null && rawCourseId.isNotEmpty) {
    final course = _courseById(rawCourseId);
    if (course != null) {
      courseCode = course.courseCode;
      courseColor = _colorFromHex(course.courseColor);
    }
  }

  return Task(
    id: doc.id,
    courseId: (rawCourseId == null || rawCourseId.isEmpty) ? null : rawCourseId,
    courseCode: courseCode,
    courseColor: courseColor,
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

String? _resolveCourseIdFromTask(Task task) {
  final id = task.courseId?.trim();
  if (id != null && id.isNotEmpty) {
    final exists = coursesNotifier.value.any((c) => c.id == id);
    if (exists) return id;
  }
  final normalizedCode = task.courseCode.trim().toUpperCase();
  if (normalizedCode.isEmpty) return null;
  final matched = coursesNotifier.value.where(
    (course) => course.courseCode.toUpperCase() == normalizedCode,
  );
  return matched.isEmpty ? null : matched.first.id;
}

Future<String?> addTask(Task task) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final docRef = _tasksCollection(user.uid).doc();
  final resolvedCourseId = _resolveCourseIdFromTask(task);
  final payload = <String, dynamic>{
    'courseId': resolvedCourseId,
    'title': task.title.trim(),
    'description': task.description?.trim(),
    'dueDateTime': Timestamp.fromDate(task.dueDateTime),
    'status': _statusToString(task.status),
    'parentTaskId': task.parentTaskId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (resolvedCourseId == null) {
    payload['courseCode'] = task.courseCode.trim().toUpperCase();
    payload['courseColor'] =
        '#${(task.courseColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
  await docRef.set(payload);
  return docRef.id;
}

Future<void> updateTask(Task task) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final resolvedCourseId = _resolveCourseIdFromTask(task);
  final payload = <String, dynamic>{
    'courseId': resolvedCourseId,
    'title': task.title.trim(),
    'description': task.description?.trim(),
    'dueDateTime': Timestamp.fromDate(task.dueDateTime),
    'status': _statusToString(task.status),
    'parentTaskId': task.parentTaskId,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (resolvedCourseId != null) {
    payload['courseCode'] = FieldValue.delete();
    payload['courseColor'] = FieldValue.delete();
  } else {
    payload['courseCode'] = task.courseCode.trim().toUpperCase();
    payload['courseColor'] =
        '#${(task.courseColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
  await _tasksCollection(user.uid).doc(task.id).set(
        payload,
        SetOptions(merge: true),
      );
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
