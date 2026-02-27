import '../models/academic_session.dart';

class TermWindow {
  const TermWindow({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
  });

  final String id;
  final String label;
  final DateTime start;
  final DateTime end;
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

List<TermWindow> buildTermWindows(AcademicSession session) {
  final start = _startOfDay(session.startDate);
  final sessionEnd = _endOfDay(session.endDate);

  DateTime clamp(DateTime date) => date.isAfter(sessionEnd) ? sessionEnd : date;

  final windows = <TermWindow>[];

  // Semester 1 term = Sem 1 teaching + Mid-sem break / Industrial training
  // 19 weeks (Sem 1) + 4 weeks (break) = 23 weeks total.
  final sem1End = clamp(start.add(const Duration(days: 23 * 7 - 1)));
  windows.add(
    TermWindow(
      id: 'sem1',
      label: 'Semester 1',
      start: start,
      end: sem1End,
    ),
  );

  // Semester 2 term = remainder of the session
  final sem2Start = sem1End.add(const Duration(days: 1));
  if (!sem2Start.isAfter(sessionEnd)) {
    windows.add(
      TermWindow(
        id: 'sem2',
        label: 'Semester 2',
        start: sem2Start,
        end: sessionEnd,
      ),
    );
  }

  if (windows.isEmpty) {
    windows.add(
      TermWindow(
        id: 'full_session',
        label: 'Full session',
        start: start,
        end: sessionEnd,
      ),
    );
  }

  return windows;
}

String defaultTermId(List<TermWindow> windows) {
  final now = DateTime.now();
  for (final term in windows) {
    if (!now.isBefore(term.start) && !now.isAfter(term.end)) {
      return term.id;
    }
  }
  return windows.first.id;
}

bool isInTerm(DateTime value, TermWindow term) {
  return !value.isBefore(term.start) && !value.isAfter(term.end);
}

DateTime clampToTerm(DateTime value, TermWindow term) {
  if (value.isBefore(term.start)) return term.start;
  if (value.isAfter(term.end)) return term.end;
  return value;
}

