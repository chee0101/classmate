import 'dart:async';

import '../models/task.dart';
import '../utils/task_utils.dart';
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
    notificationPreferencesNotifier.addListener(_scheduleFromTasksWithDebounce);
    _scheduleFromTasksWithDebounce();
  }

  void _scheduleFromTasksWithDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await NotificationService.instance.initialize();
      await NotificationService.instance.cancelAllTaskReminders();
      final prefs = notificationPreferencesNotifier.value;
      if (!prefs.enabled) return;

      final tasks = tasksNotifier.value
          .where((task) => task.parentTaskId == null)
          .where((task) => TaskUtils.effectiveStatus(task) != TaskStatus.completed)
          .toList(growable: false);
      final leadTime = Duration(minutes: prefs.leadTimeMinutes);

      for (final task in tasks) {
        await NotificationService.instance.scheduleTaskReminder(
          task: task,
          leadTime: leadTime,
        );
      }
    });
  }
}
