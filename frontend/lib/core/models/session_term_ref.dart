import 'academic_session.dart';
import '../utils/term_windows.dart';

/// Simple helper struct pairing a session with one of its term windows.
class SessionTermRef {
  const SessionTermRef({
    required this.session,
    required this.term,
  });

  final AcademicSession session;
  final TermWindow term;
}
