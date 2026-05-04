import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.enabled,
    required this.leadTimeMinutes,
  });

  static const NotificationPreferences defaults = NotificationPreferences(
    enabled: true,
    leadTimeMinutes: 30,
  );

  final bool enabled;
  final int leadTimeMinutes;

  NotificationPreferences copyWith({
    bool? enabled,
    int? leadTimeMinutes,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      leadTimeMinutes: leadTimeMinutes ?? this.leadTimeMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'leadTimeMinutes': leadTimeMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static NotificationPreferences fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final lead = (json['leadTimeMinutes'] as num?)?.toInt() ?? defaults.leadTimeMinutes;
    return NotificationPreferences(
      enabled: (json['enabled'] as bool?) ?? defaults.enabled,
      leadTimeMinutes: lead.clamp(5, 7 * 24 * 60),
    );
  }
}

final ValueNotifier<NotificationPreferences> notificationPreferencesNotifier =
    ValueNotifier<NotificationPreferences>(NotificationPreferences.defaults);

StreamSubscription<User?>? _authSubscription;
StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _prefsSubscription;

DocumentReference<Map<String, dynamic>> _prefsDoc(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('notifications');
}

void initializeNotificationPreferencesSync() {
  if (_authSubscription != null) return;

  _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
    _prefsSubscription?.cancel();
    _prefsSubscription = null;

    if (user == null) {
      notificationPreferencesNotifier.value = NotificationPreferences.defaults;
      return;
    }

    _prefsSubscription = _prefsDoc(user.uid).snapshots().listen((snapshot) {
      notificationPreferencesNotifier.value =
          NotificationPreferences.fromJson(snapshot.data());
    });
  });
}

Future<void> updateNotificationPreferences(NotificationPreferences next) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  // Optimistic local update so switches/dropdowns do not bounce during sync delays.
  notificationPreferencesNotifier.value = next;
  await _prefsDoc(user.uid).set(
    next.toJson(),
    SetOptions(merge: true),
  );
}
