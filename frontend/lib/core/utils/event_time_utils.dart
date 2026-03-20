import '../models/academic_event.dart';
import 'day_bounds_utils.dart';

int minutesSinceMidnight(DateTime dt) => dt.hour * 60 + dt.minute;

/// Returns the time range of [event] clipped to [day] as minutes since midnight.
///
/// Uses half-open intervals on the minute scale: [startMinutes, endMinutesExclusive).
({int startMinutes, int endMinutesExclusive}) eventTimeRangeForDay(
  AcademicEvent event,
  DateTime day,
) {
  final dayStart = startOfDay(day);
  final dayEndExclusive = dayStart.add(const Duration(days: 1));

  if (event.allDay) {
    return (startMinutes: 0, endMinutesExclusive: 24 * 60);
  }

  final effectiveStart =
      event.startDateTime.isAfter(dayStart) ? event.startDateTime : dayStart;
  final effectiveEndExclusive = event.endDateTime.isBefore(dayEndExclusive)
      ? event.endDateTime
      : dayEndExclusive;

  final startMin = minutesSinceMidnight(effectiveStart);
  final endMin = effectiveEndExclusive == dayEndExclusive
      ? 24 * 60
      : minutesSinceMidnight(effectiveEndExclusive);

  return (startMinutes: startMin, endMinutesExclusive: endMin);
}

/// Half-open interval overlap check on the minute / numeric timeline.
bool intervalsOverlap(
  int startA,
  int endA,
  int startB,
  int endB,
) {
  return startA < endB && endA > startB;
}

/// True when [innerStart, innerEnd] is fully contained in [outerStart, outerEnd].
bool isFullContain(
  int innerStart,
  int innerEnd,
  int outerStart,
  int outerEnd,
) {
  return outerStart <= innerStart && outerEnd >= innerEnd;
}

/// True when [innerStart, innerEnd] is fully within the event time range.
///
/// Treats DateTime ranges with inclusive endpoints using:
/// - innerStart >= outerStart
/// - innerEnd <= outerEnd
bool isFullyWithinDateTimeRange(
  DateTime innerStart,
  DateTime innerEnd,
  DateTime outerStart,
  DateTime outerEnd,
) {
  if (!outerEnd.isAfter(outerStart)) return false;
  return !innerStart.isBefore(outerStart) && !innerEnd.isAfter(outerEnd);
}

/// True when the given DateTime range is fully covered by any event in [events].
bool isFullyCoveredByAnyEvent({
  required DateTime innerStart,
  required DateTime innerEnd,
  required List<AcademicEvent> events,
}) {
  for (final event in events) {
    if (event.allDay) return true;
    if (isFullyWithinDateTimeRange(
      innerStart,
      innerEnd,
      event.startDateTime,
      event.endDateTime,
    )) {
      return true;
    }
  }
  return false;
}

