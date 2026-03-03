import '../../core/models/academic_session.dart';
import '../../core/utils/term_windows.dart';

/// Simple helper struct used in HomeScreen to pair a session with one of its term windows.
class SessionTermRef {
  const SessionTermRef({
    required this.session,
    required this.term,
  });

  final AcademicSession session;
  final TermWindow term;
}

