import '../models/academic_session.dart';
import '../models/session_term_ref.dart';
import 'term_windows.dart';

/// Build all (session, term) refs from a list of sessions.
List<SessionTermRef> buildAllSessionTermRefs(List<AcademicSession> sessions) {
  final refs = <SessionTermRef>[];
  for (final session in sessions) {
    for (final term in buildTermWindows(session)) {
      refs.add(SessionTermRef(session: session, term: term));
    }
  }
  return refs;
}

/// Resolve the default (session, term) to show, based on "today".
///
/// Priority:
/// 1) A term that contains today's date.
/// 2) If none, the nearest future term (smallest positive distance from start).
/// 3) If none, the nearest past term (smallest distance from end).
SessionTermRef resolveDefaultSessionTermRef(List<SessionTermRef> refs, DateTime now) {
  if (refs.isEmpty) {
    throw ArgumentError('refs must not be empty');
  }

  // 1) Term that contains today
  for (final ref in refs) {
    if (!now.isBefore(ref.term.start) && !now.isAfter(ref.term.end)) {
      return ref;
    }
  }

  // 2) Nearest future term
  SessionTermRef? futureBest;
  Duration? minFuture;
  for (final ref in refs) {
    if (ref.term.start.isAfter(now)) {
      final diff = ref.term.start.difference(now);
      if (minFuture == null || diff < minFuture) {
        minFuture = diff;
        futureBest = ref;
      }
    }
  }
  if (futureBest != null) return futureBest;

  // 3) Nearest past term
  SessionTermRef pastBest = refs.first;
  Duration? minPast;
  for (final ref in refs) {
    if (ref.term.end.isBefore(now)) {
      final diff = now.difference(ref.term.end);
      if (minPast == null || diff < minPast) {
        minPast = diff;
        pastBest = ref;
      }
    }
  }
  return pastBest;
}

