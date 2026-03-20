import 'term_windows.dart';

/// Builds the week banner text shown on the Schedule screen.
///
/// Example: `Week 3 - Teaching & Learning`
String buildWeekBannerText(TermWindow term, DateTime date) {
  final startOfTerm = DateTime(term.start.year, term.start.month, term.start.day);
  final currentDay = DateTime(date.year, date.month, date.day);

  if (currentDay.isBefore(startOfTerm) || currentDay.isAfter(term.end)) {
    return '';
  }

  final daysDiff = currentDay.difference(startOfTerm).inDays;
  final weekNumber = (daysDiff ~/ 7) + 1;

  String segmentLabel;
  if (term.id == 'sem1' || term.label.toLowerCase().contains('semester 1')) {
    // Semester 1 pattern:
    // 1-7: T&L, 8: Mid-sem break, 9-15: T&L, 16: Revision, 17-19: Exam, 20-23: Break.
    if (weekNumber >= 1 && weekNumber <= 7) {
      segmentLabel = 'Teaching & Learning';
    } else if (weekNumber == 8) {
      segmentLabel = 'Mid-Semester Break';
    } else if (weekNumber >= 9 && weekNumber <= 15) {
      segmentLabel = 'Teaching & Learning';
    } else if (weekNumber == 16) {
      segmentLabel = 'Revision Week';
    } else if (weekNumber >= 17 && weekNumber <= 19) {
      segmentLabel = 'Exam Week';
    } else {
      segmentLabel = 'Mid-Semester Break';
    }
  } else if (term.id == 'sem2' ||
      term.label.toLowerCase().contains('semester 2')) {
    // Semester 2 pattern:
    // 1-7: T&L, 8: Mid-sem break, 9-15: T&L, 16: Revision, 17-19: Exam, 20+: Long break.
    if (weekNumber >= 1 && weekNumber <= 7) {
      segmentLabel = 'Teaching & Learning';
    } else if (weekNumber == 8) {
      segmentLabel = 'Mid-Semester Break';
    } else if (weekNumber >= 9 && weekNumber <= 15) {
      segmentLabel = 'Teaching & Learning';
    } else if (weekNumber == 16) {
      segmentLabel = 'Revision Week';
    } else if (weekNumber >= 17 && weekNumber <= 19) {
      segmentLabel = 'Exam Week';
    } else {
      segmentLabel = 'Break';
    }
  } else {
    segmentLabel = '';
  }

  return segmentLabel != '' ? 'Week $weekNumber - $segmentLabel' : '';
}

