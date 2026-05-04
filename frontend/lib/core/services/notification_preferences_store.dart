import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.task,
    required this.event,
    required this.classReminder,
  });

  static const NotificationPreferences defaults = NotificationPreferences(
    task: NotificationTypePreferences(
      enabled: true,
      leadTimeMinutes: 30,
    ),
    event: NotificationTypePreferences(
      enabled: true,
      leadTimeMinutes: 60,
    ),
    classReminder: NotificationTypePreferences(
      enabled: false,
      leadTimeMinutes: 10,
    ),
  );

  final NotificationTypePreferences task;
  final NotificationTypePreferences event;
  final NotificationTypePreferences classReminder;

  NotificationPreferences copyWith({
    NotificationTypePreferences? task,
    NotificationTypePreferences? event,
    NotificationTypePreferences? classReminder,
  }) {
    return NotificationPreferences(
      task: task ?? this.task,
      event: event ?? this.event,
      classReminder: classReminder ?? this.classReminder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task': task.toJson(),
      'event': event.toJson(),
      'class': classReminder.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static NotificationPreferences fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final legacyEnabled = (json['enabled'] as bool?) ?? true;
    final legacyLead = (json['leadTimeMinutes'] as num?)?.toInt() ?? 30;
    return NotificationPreferences(
      task: NotificationTypePreferences.fromJson(
        json['task'] as Map<String, dynamic>?,
        fallbackEnabled: legacyEnabled,
        fallbackLeadTimeMinutes: legacyLead,
      ),
      event: NotificationTypePreferences.fromJson(
        json['event'] as Map<String, dynamic>?,
        fallbackEnabled: defaults.event.enabled,
        fallbackLeadTimeMinutes: defaults.event.leadTimeMinutes,
      ),
      classReminder: NotificationTypePreferences.fromJson(
        json['class'] as Map<String, dynamic>?,
        fallbackEnabled: defaults.classReminder.enabled,
        fallbackLeadTimeMinutes: defaults.classReminder.leadTimeMinutes,
      ),
    );
  }
}

class NotificationTypePreferences {
  const NotificationTypePreferences({
    required this.enabled,
    required this.leadTimeMinutes,
  });

  final bool enabled;
  final int leadTimeMinutes;

  NotificationTypePreferences copyWith({
    bool? enabled,
    int? leadTimeMinutes,
  }) {
    return NotificationTypePreferences(
      enabled: enabled ?? this.enabled,
      leadTimeMinutes: leadTimeMinutes ?? this.leadTimeMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'leadTimeMinutes': leadTimeMinutes,
    };
  }

  static NotificationTypePreferences fromJson(
    Map<String, dynamic>? json, {
    required bool fallbackEnabled,
    required int fallbackLeadTimeMinutes,
  }) {
    final lead =
        (json?['leadTimeMinutes'] as num?)?.toInt() ?? fallbackLeadTimeMinutes;
    return NotificationTypePreferences(
      enabled: (json?['enabled'] as bool?) ?? fallbackEnabled,
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
      .collection('notificationPreferences')
      .doc('main');
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
