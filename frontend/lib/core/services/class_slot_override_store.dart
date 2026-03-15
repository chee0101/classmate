import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/class_slot_override.dart';

final ValueNotifier<List<ClassSlotOverride>> classSlotOverridesNotifier =
    ValueNotifier<List<ClassSlotOverride>>([]);

StreamSubscription<User?>? _overrideAuthSubscription;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _overridesSubscription;

CollectionReference<Map<String, dynamic>> _overridesCollection(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('classSlotOverrides');
}

void initializeClassSlotOverridesSync() {
  if (_overrideAuthSubscription != null) return;

  _overrideAuthSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
    _overridesSubscription?.cancel();
    _overridesSubscription = null;

    if (user == null) {
      classSlotOverridesNotifier.value = const <ClassSlotOverride>[];
      return;
    }

    _overridesSubscription = _overridesCollection(user.uid).snapshots().listen((snapshot) {
      classSlotOverridesNotifier.value = snapshot.docs
          .map(_overrideFromDoc)
          .whereType<ClassSlotOverride>()
          .toList(growable: false);
    });
  });
}

ClassSlotOverride? _overrideFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final classSlotId = (data['classSlotId'] as String?)?.trim() ?? '';
  final occurrenceDateRaw = data['occurrenceDate'] as Timestamp?;
  final overrideDateRaw = data['overrideDate'] as Timestamp?;
  final actionRaw = (data['action'] as String?)?.trim().toLowerCase();
  if (classSlotId.isEmpty ||
      occurrenceDateRaw == null ||
      actionRaw == null ||
      actionRaw.isEmpty) {
    return null;
  }
  final action = actionRaw == ClassSlotOverrideAction.cancel.name
      ? ClassSlotOverrideAction.cancel
      : ClassSlotOverrideAction.edit;
  final occurrenceDate = occurrenceDateRaw.toDate().toLocal();
  final overrideDate = overrideDateRaw?.toDate().toLocal();

  return ClassSlotOverride(
    id: doc.id,
    classSlotId: classSlotId,
    occurrenceDate: DateTime(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day),
    action: action,
    overrideDate: overrideDate == null
        ? null
        : DateTime(overrideDate.year, overrideDate.month, overrideDate.day),
    overrideStartMinutes: (data['overrideStartMinutes'] as num?)?.toInt(),
    overrideEndMinutes: (data['overrideEndMinutes'] as num?)?.toInt(),
    overrideMode: (data['overrideMode'] as String?)?.trim(),
    overrideVenue: (data['overrideVenue'] as String?)?.trim(),
  );
}

Future<void> upsertClassSlotOverride(ClassSlotOverride override) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  await _overridesCollection(user.uid).doc(override.id).set({
    'classSlotId': override.classSlotId.trim(),
    'occurrenceKey': override.occurrenceKey,
    'occurrenceDate': Timestamp.fromDate(
      DateTime(
        override.occurrenceDate.year,
        override.occurrenceDate.month,
        override.occurrenceDate.day,
      ),
    ),
    'overrideDate': override.overrideDate == null
        ? null
        : Timestamp.fromDate(
            DateTime(
              override.overrideDate!.year,
              override.overrideDate!.month,
              override.overrideDate!.day,
            ),
          ),
    'action': override.action.name,
    'overrideStartMinutes': override.overrideStartMinutes,
    'overrideEndMinutes': override.overrideEndMinutes,
    'overrideMode': (override.overrideMode ?? '').trim().isEmpty
        ? null
        : override.overrideMode!.trim(),
    'overrideVenue': (override.overrideVenue ?? '').trim().isEmpty
        ? null
        : override.overrideVenue!.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> deleteClassSlotOverridesForClassSlotId({
  required String classSlotId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final snapshot = await _overridesCollection(user.uid)
      .where('classSlotId', isEqualTo: classSlotId.trim())
      .get();
  if (snapshot.docs.isEmpty) return;

  final batch = FirebaseFirestore.instance.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}
