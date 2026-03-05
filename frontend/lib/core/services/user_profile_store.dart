import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileStore {
  const UserProfileStore._();

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static Future<void> ensureForUser(
    User user, {
    String? preferredUsername,
  }) async {
    final email = (user.email ?? '').trim();
    final username = _resolveUsername(
      preferredUsername: preferredUsername,
      displayName: user.displayName,
      email: email,
    );
    final ref = _users.doc(user.uid);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await ref.set({
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await ref.set({
      'username': username,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateUsernameForCurrentUser(String username) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _users.doc(user.uid).set({
      'username': username.trim(),
      'email': (user.email ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _resolveUsername({
    required String? preferredUsername,
    required String? displayName,
    required String email,
  }) {
    final preferred = preferredUsername?.trim() ?? '';
    if (preferred.isNotEmpty) return preferred;

    final display = displayName?.trim() ?? '';
    if (display.isNotEmpty) return display;

    if (email.isNotEmpty) return email.split('@').first;
    return 'Student';
  }
}
