import 'package:flutter/foundation.dart';

import '../models/academic_session.dart';

final ValueNotifier<AcademicSession?> currentAcademicSessionNotifier =
    ValueNotifier<AcademicSession?>(null);

final List<AcademicSession> mockAcademicSessions = [];

bool hasAcademicSession() => currentAcademicSessionNotifier.value != null;

void setCurrentAcademicSession(AcademicSession session) {
  currentAcademicSessionNotifier.value = session;
  final exists = mockAcademicSessions.any((s) => s.id == session.id);
  if (!exists) {
    mockAcademicSessions.add(session);
  }
}

