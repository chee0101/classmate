import 'package:flutter/foundation.dart';

class SessionTermSelection {
  const SessionTermSelection({
    required this.sessionId,
    required this.termId,
  });

  final String sessionId;
  final String termId;
}

final ValueNotifier<SessionTermSelection?> selectedSessionTermNotifier =
    ValueNotifier<SessionTermSelection?>(null);

void setSelectedSessionTerm({
  required String sessionId,
  required String termId,
}) {
  selectedSessionTermNotifier.value = SessionTermSelection(
    sessionId: sessionId,
    termId: termId,
  );
}

void clearSelectedSessionTerm() {
  selectedSessionTermNotifier.value = null;
}
