import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/routes.dart';
import '../models/task.dart';
import '../services/task_store.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Handles local notification taps: task → task detail; event/class → home tab.
class NotificationNavigationCoordinator {
  NotificationNavigationCoordinator._();

  static void Function()? _switchToHomeTab;
  static String? _pendingLaunchPayload;

  static VoidCallback? _taskRetryListener;
  static Timer? _taskRetryCleanupTimer;

  static void registerHomeTab(void Function()? fn) {
    _switchToHomeTab = fn;
  }

  static void setPendingLaunchPayload(String payload) {
    if (payload.isEmpty) return;
    _pendingLaunchPayload = payload;
  }

  /// Call from [MainScaffold] after the shell is mounted and the home callback is registered.
  static void consumePendingLaunchPayload() {
    final p = _pendingLaunchPayload;
    if (p == null || p.isEmpty) return;
    _pendingLaunchPayload = null;
    handlePayload(p);
  }

  static void handlePayload(String? raw) {
    final payload = (raw ?? '').trim();
    if (payload.isEmpty) return;

    if (payload.startsWith('debug')) {
      return;
    }

    // Foreground FCM uses arbitrary `data[type]` strings — avoid treating as task ids.
    if (payload.startsWith('fcm')) {
      final nav = appNavigatorKey.currentState;
      if (nav != null) _goHome(nav);
      return;
    }

    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      _pendingLaunchPayload = payload;
      return;
    }

    if (payload.startsWith('event:') || payload.startsWith('class:')) {
      _goHome(nav);
      return;
    }

    String? taskId;
    if (payload.startsWith('task:')) {
      taskId = payload.substring(5);
    } else if (!payload.contains(':')) {
      taskId = payload;
    }

    if (taskId != null && taskId.isNotEmpty) {
      final task = _findTask(taskId);
      if (task != null) {
        nav.pushNamed(AppRoutes.taskDetail, arguments: task);
        return;
      }
      _scheduleTaskRetry(taskId);
      return;
    }

    _goHome(nav);
  }

  static Task? _findTask(String id) {
    for (final t in tasksNotifier.value) {
      if (t.id == id) return t;
    }
    return null;
  }

  static void _scheduleTaskRetry(String taskId) {
    _cancelTaskRetry();
    void listener() {
      final task = _findTask(taskId);
      if (task == null) return;
      _cancelTaskRetry();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigatorKey.currentState?.pushNamed(
          AppRoutes.taskDetail,
          arguments: task,
        );
      });
    }

    _taskRetryListener = listener;
    tasksNotifier.addListener(listener);
    _taskRetryCleanupTimer = Timer(const Duration(seconds: 30), _cancelTaskRetry);
  }

  static void _cancelTaskRetry() {
    _taskRetryCleanupTimer?.cancel();
    _taskRetryCleanupTimer = null;
    final l = _taskRetryListener;
    if (l != null) {
      tasksNotifier.removeListener(l);
      _taskRetryListener = null;
    }
  }

  static void _goHome(NavigatorState nav) {
    nav.popUntil((route) => route.isFirst);
    _switchToHomeTab?.call();
  }
}
