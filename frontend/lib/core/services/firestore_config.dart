import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

bool _firestorePersistenceConfigured = false;

/// Enables Firestore local persistence and a generous on-disk cache.
///
/// Call once after [Firebase.initializeApp] and **before** any reads, writes, or
/// [FirebaseFirestore.instance] snapshot listeners. On Android/iOS this keeps
/// data available offline and queues writes until the network returns.
///
/// Safe to call multiple times; subsequent calls are ignored if configuration
/// already succeeded.
void configureFirestorePersistence() {
  if (_firestorePersistenceConfigured) return;
  if (Firebase.apps.isEmpty) return;

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    _firestorePersistenceConfigured = true;
  } catch (_) {
    // Settings can only be applied before first use; hot restart or platform
    // limits may cause this to fail — default SDK behavior still applies.
  }
}
