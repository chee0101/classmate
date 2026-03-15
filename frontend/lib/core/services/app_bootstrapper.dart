import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import 'academic_event_store.dart';
import 'academic_session_store.dart';
import 'class_slot_store.dart';
import 'class_slot_override_store.dart';
import 'course_store.dart';
import 'task_store.dart';

/// Runs one-time app bootstrapping work after the first Flutter frame.
///
/// Goal: keep `main()` minimal so the Android native splash can disappear fast,
/// while showing a Flutter splash/loading screen during initialization.
class AppBootstrapper {
  AppBootstrapper._();

  static final AppBootstrapper instance = AppBootstrapper._();

  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  bool _started = false;
  bool _completed = false;

  bool get isCompleted => _completed;

  /// Start the bootstrap after the first frame to avoid delaying first paint.
  void startAfterFirstFrame() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fire-and-forget; the splash screen can listen to [progress].
      _run();
    });
  }

  Future<void> _run() async {
    try {
      _setProgress(0.15);
      await Future<void>.delayed(Duration.zero);

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _setProgress(0.50);
      await Future<void>.delayed(Duration.zero);

      // These are lightweight listener registrations. Keep them after first frame.
      initializeAcademicSessionsSync();
      _setProgress(0.62);
      await Future<void>.delayed(Duration.zero);

      initializeCoursesSync();
      _setProgress(0.70);
      await Future<void>.delayed(Duration.zero);

      initializeClassSlotsSync();
      _setProgress(0.78);
      await Future<void>.delayed(Duration.zero);

      initializeClassSlotOverridesSync();
      _setProgress(0.82);
      await Future<void>.delayed(Duration.zero);

      initializeTasksSync();
      _setProgress(0.89);
      await Future<void>.delayed(Duration.zero);

      initializeAcademicEventsSync();
      _setProgress(0.95);
      await Future<void>.delayed(Duration.zero);

      _setProgress(1.0);
      _completed = true;
    } catch (_) {
      // Don't crash the app on bootstrap issues; keep progress where it is.
      // Screens that depend on data should handle empty states gracefully.
      _completed = true;
    }
  }

  void _setProgress(double value) {
    progress.value = value.clamp(0.0, 1.0);
  }
}

