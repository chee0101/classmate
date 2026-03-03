import 'package:flutter/foundation.dart';

import '../models/academic_session.dart';

final ValueNotifier<AcademicSession?> currentAcademicSessionNotifier =
    ValueNotifier<AcademicSession?>(null);

final ValueNotifier<List<AcademicSession>> mockAcademicSessionsNotifier =
    ValueNotifier<List<AcademicSession>>([]);

// For backward compatibility
List<AcademicSession> get mockAcademicSessions => mockAcademicSessionsNotifier.value;

bool hasAcademicSession() => currentAcademicSessionNotifier.value != null;

void setCurrentAcademicSession(AcademicSession session) {
  currentAcademicSessionNotifier.value = session;
  final exists = mockAcademicSessionsNotifier.value.any((s) => s.id == session.id);
  if (!exists) {
    mockAcademicSessionsNotifier.value = [
      ...mockAcademicSessionsNotifier.value,
      session,
    ];
  }
}

void addAcademicSession(AcademicSession session) {
  final exists = mockAcademicSessionsNotifier.value.any((s) => s.id == session.id);
  if (!exists) {
    mockAcademicSessionsNotifier.value = [
      ...mockAcademicSessionsNotifier.value,
      session,
    ];
    
    // Automatically set as current session if no current session exists
    if (currentAcademicSessionNotifier.value == null) {
      currentAcademicSessionNotifier.value = session;
    }
  }
}

void updateAcademicSession(AcademicSession updatedSession) {
  final index = mockAcademicSessionsNotifier.value
      .indexWhere((s) => s.id == updatedSession.id);
  if (index != -1) {
    final updated = List<AcademicSession>.from(mockAcademicSessionsNotifier.value);
    updated[index] = updatedSession;
    mockAcademicSessionsNotifier.value = updated;
    
    // Also update if it's the current session
    if (currentAcademicSessionNotifier.value?.id == updatedSession.id) {
      currentAcademicSessionNotifier.value = updatedSession;
    }
  }
}

void deleteAcademicSession(String sessionId) {
  mockAcademicSessionsNotifier.value = mockAcademicSessionsNotifier.value
      .where((s) => s.id != sessionId)
      .toList();
  
  // Clear current session if it was deleted
  if (currentAcademicSessionNotifier.value?.id == sessionId) {
    currentAcademicSessionNotifier.value = null;
  }
}
