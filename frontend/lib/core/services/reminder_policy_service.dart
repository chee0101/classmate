import 'dart:async';

import '../models/academic_session.dart';
import '../models/class_slot_override.dart';
import '../models/timetable_entry.dart';
import '../models/task.dart';
import '../utils/date_time_format.dart';
import '../utils/term_windows.dart';
import '../utils/task_utils.dart';
import 'academic_event_store.dart';
import 'academic_session_store.dart';
import 'class_slot_override_store.dart';
import 'class_slot_store.dart';
import 'notification_service.dart';
import 'notification_preferences_store.dart';
import 'task_store.dart';

class ReminderPolicyService {
  ReminderPolicyService._();

  static final ReminderPolicyService instance = ReminderPolicyService._();

  bool _started = false;
  Timer? _debounceTimer;

  void start() {
    if (_started) return;
    _started = true;
    tasksNotifier.addListener(_scheduleFromTasksWithDebounce);
    academicEventsNotifier.addListener(_scheduleFromTasksWithDebounce);
    timetablesNotifier.addListener(_scheduleFromTasksWithDebounce);
    academicSessionsNotifier.addListener(_scheduleFromTasksWithDebounce);
    classSlotOverridesNotifier.addListener(_scheduleFromTasksWithDebounce);
    notificationPreferencesNotifier.addListener(_scheduleFromTasksWithDebounce);
    _scheduleFromTasksWithDebounce();
  }

  void _scheduleFromTasksWithDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await NotificationService.instance.initialize();
      await NotificationService.instance.cancelAllTaskReminders();
      final prefs = notificationPreferencesNotifier.value;
      final now = DateTime.now();

      if (prefs.task.enabled) {
        final tasks = tasksNotifier.value
            .where((task) => task.parentTaskId == null)
            .where((task) => TaskUtils.effectiveStatus(task) != TaskStatus.completed)
            .toList(growable: false);
        final leadTime = Duration(minutes: prefs.task.leadTimeMinutes);

        for (final task in tasks) {
          await NotificationService.instance.scheduleTaskReminder(
            task: task,
            leadTime: leadTime,
          );
        }
      }

      if (prefs.event.enabled) {
        final leadTime = Duration(minutes: prefs.event.leadTimeMinutes);
        for (final event in academicEventsNotifier.value) {
          await NotificationService.instance.scheduleEventReminder(
            event: event,
            leadTime: leadTime,
          );
        }
      }

      if (prefs.classReminder.enabled) {
        final leadTime = Duration(minutes: prefs.classReminder.leadTimeMinutes);
        final sessionsById = <String, AcademicSession>{
          for (final session in academicSessionsNotifier.value) session.id: session,
        };
        final maxDate = now.add(const Duration(days: 21));
        final overrides = classSlotOverridesNotifier.value;
        final overrideById = <String, ClassSlotOverride>{
          for (final o in overrides) o.id: o,
        };
        final overrideByOccurrence = <String, ClassSlotOverride>{
          for (final o in overrides) o.occurrenceKey: o,
        };

        for (final entry in timetablesNotifier.value) {
          final session = sessionsById[entry.sessionId];
          if (session == null) continue;
          final windows = buildTermWindows(session);
          TermWindow? term;
          for (final window in windows) {
            if (window.id == entry.termId) {
              term = window;
              break;
            }
          }
          if (term == null) continue;

          final startDate = _startOfDay(now).isAfter(term.start)
              ? _startOfDay(now)
              : _startOfDay(term.start);
          final endDate = _startOfDay(maxDate).isBefore(term.end)
              ? _startOfDay(maxDate)
              : _startOfDay(term.end);
          if (endDate.isBefore(startDate)) continue;

          final termStartDay = _startOfDay(term.start);
          final termEndDay = _startOfDay(term.end);

          for (final slot in entry.slots) {
            final weekdayIndex = _weekdayToDateTimeWeekday(slot.day);
            final startMinutes = parseTimeLabel12hToMinutes(slot.startTime);
            if (weekdayIndex == null || startMinutes == null) continue;

            for (
              var date = startDate;
              !date.isAfter(endDate);
              date = date.add(const Duration(days: 1))
            ) {
              if (date.weekday != weekdayIndex) continue;

              final occurrenceKey = ClassSlotOverride.buildClassSlotOccurrenceKey(
                classSlotId: slot.classSlotId,
                occurrenceDate: date,
              );
              final overrideId = ClassSlotOverride.buildClassSlotOverrideId(
                classSlotId: slot.classSlotId,
                occurrenceDate: date,
              );
              final override =
                  overrideById[overrideId] ?? overrideByOccurrence[occurrenceKey];
              if (override?.action == ClassSlotOverrideAction.cancel) {
                continue;
              }

              final overrideDate = override?.overrideDate;
              final renderDate = overrideDate == null
                  ? date
                  : DateTime(
                      overrideDate.year,
                      overrideDate.month,
                      overrideDate.day,
                    );

              if (renderDate.isBefore(termStartDay) || renderDate.isAfter(termEndDay)) {
                continue;
              }
              if (renderDate.isBefore(startDate) || renderDate.isAfter(endDate)) {
                continue;
              }

              final effectiveStartMinutes =
                  override?.overrideStartMinutes ?? startMinutes;
              final classStart = DateTime(
                renderDate.year,
                renderDate.month,
                renderDate.day,
                effectiveStartMinutes ~/ 60,
                effectiveStartMinutes % 60,
              );
              await NotificationService.instance.scheduleClassReminder(
                classSlotId: slot.classSlotId,
                courseCode: entry.courseCode,
                classStart: classStart,
                leadTime: leadTime,
              );
            }
          }
        }
      }
    });
  }

  static DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static int? _weekdayToDateTimeWeekday(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        return null;
    }
  }
}
