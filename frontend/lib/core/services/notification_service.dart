import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/academic_event.dart';
import '../models/task.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _taskReminderChannelId = 2001;
  static const String _taskReminderChannelName = 'Task reminders';
  static const String _taskReminderChannelDescription =
      'Deadline reminder notifications for tasks';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundFcmSubscription;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final nowLocal = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(_tzName(nowLocal)));
    } catch (_) {
      // Fallback from offset (e.g. UTC+8 => Etc/GMT-8; sign is reversed in Etc/GMT IDs).
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      final etcName = offsetHours >= 0 ? 'Etc/GMT-$offsetHours' : 'Etc/GMT+${-offsetHours}';
      try {
        tz.setLocalLocation(tz.getLocation(etcName));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(settings: initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_reminders',
        _taskReminderChannelName,
        description: _taskReminderChannelDescription,
        importance: Importance.high,
      ),
    );

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foregroundFcmSubscription?.cancel();
    _foregroundFcmSubscription = FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      final title = (notification?.title ?? 'ClassMate').trim();
      final body = (notification?.body ?? '').trim();
      if (title.isEmpty && body.isEmpty) return;
      await _showFcmForegroundNotification(
        title: title.isEmpty ? 'ClassMate' : title,
        body: body.isEmpty ? 'You have a new update.' : body,
        payload: message.data['type']?.toString() ?? 'fcm_foreground',
      );
    });

    _initialized = true;
  }

  Future<void> cancelAllTaskReminders() async {
    await _plugin.cancelAll();
  }

  Future<void> scheduleTaskReminder({
    required Task task,
    required Duration leadTime,
  }) async {
    final remindAt = task.dueDateTime.subtract(leadTime);
    final now = DateTime.now();
    if (!remindAt.isAfter(now)) return;

    final id = _taskNotificationId(task.id);
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      _taskReminderChannelName,
      channelDescription: _taskReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: 'Almost due: ${task.title}',
      body:
          '${task.courseCode} is due in ${_formatLeadTime(leadTime)} at ${_formatTime(task.dueDateTime)}',
      scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id,
    );
  }

  Future<void> scheduleEventReminder({
    required AcademicEvent event,
    required Duration leadTime,
  }) async {
    final remindAt = event.startDateTime.subtract(leadTime);
    if (!remindAt.isAfter(DateTime.now())) return;

    final id = _eventNotificationId(event.id);
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      _taskReminderChannelName,
      channelDescription: _taskReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: 'Upcoming event: ${event.title}',
      body: 'Starts in ${_formatLeadTime(leadTime)} at ${_formatTime(event.startDateTime)}',
      scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'event:${event.id}',
    );
  }

  Future<void> scheduleClassReminder({
    required String classSlotId,
    required String courseCode,
    required DateTime classStart,
    required Duration leadTime,
  }) async {
    final now = DateTime.now();
    final remindAt = classStart.subtract(leadTime);
    DateTime scheduledAt;
    if (remindAt.isAfter(now)) {
      scheduledAt = remindAt;
    } else {
      if (!classStart.isAfter(now)) return;
      final oneMinuteBeforeStart = classStart.subtract(const Duration(minutes: 1));
      scheduledAt = oneMinuteBeforeStart.isAfter(now)
          ? oneMinuteBeforeStart
          : now.add(const Duration(seconds: 5));
    }

    final id = _classNotificationId(classSlotId, classStart);
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      _taskReminderChannelName,
      channelDescription: _taskReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: 'Class starting soon: $courseCode',
      body: 'Starts in ${_formatLeadTime(leadTime)} at ${_formatTime(classStart)}',
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'class:$classSlotId:${classStart.toIso8601String()}',
    );
  }

  Future<void> scheduleDebugTestNotification({
    Duration delay = const Duration(seconds: 10),
  }) async {
    if (delay <= const Duration(minutes: 1)) {
      // OEM/Exact-alarm restrictions can block very short scheduled notifications.
      // Use an in-app delayed local notification for deterministic debug validation.
      unawaited(
        Future<void>.delayed(delay, () async {
          await _showDebugTestNotification(
            id: 900001,
            body: 'Delayed test notification fired.',
            payload: 'debug_delayed',
          );
        }),
      );
      return;
    }

    final when = tz.TZDateTime.now(tz.local).add(delay);
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      _taskReminderChannelName,
      channelDescription: _taskReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.zonedSchedule(
      id: 900001,
      title: 'ClassMate test notification',
      body: 'If you see this, local reminders are working.',
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'debug_test',
    );
  }

  Future<void> showDebugTestNotificationNow() async {
    await _showDebugTestNotification(
      id: 900000,
      body: 'Immediate test notification.',
      payload: 'debug_now',
    );
  }

  Future<void> _showDebugTestNotification({
    required int id,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      _taskReminderChannelName,
      channelDescription: _taskReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(
      id: id,
      title: 'ClassMate test notification',
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> _showFcmForegroundNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      _taskReminderChannelName,
      channelDescription: _taskReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static int _taskNotificationId(String taskId) {
    final id = taskId.hashCode & 0x7fffffff;
    return _taskReminderChannelId + (id % 900000);
  }

  static int _eventNotificationId(String eventId) {
    final id = eventId.hashCode & 0x7fffffff;
    return _taskReminderChannelId + (id % 900000);
  }

  static int _classNotificationId(String classSlotId, DateTime classStart) {
    final key = '$classSlotId|${classStart.toIso8601String()}';
    final id = key.hashCode & 0x7fffffff;
    return _taskReminderChannelId + (id % 900000);
  }

  static String _formatTime(DateTime value) {
    final h = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final m = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  static String _formatLeadTime(Duration leadTime) {
    final totalMinutes = leadTime.inMinutes;
    if (totalMinutes % 60 == 0) {
      final hours = totalMinutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    return '$totalMinutes minutes';
  }

  static String _tzName(String dartTzName) {
    // On most targets, this matches an IANA identifier already.
    // Fallback path handled by caller.
    if (dartTzName.trim().isEmpty) return 'UTC';
    if (kIsWeb) return 'UTC';
    return dartTzName;
  }
}
