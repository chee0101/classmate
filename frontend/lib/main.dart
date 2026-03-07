import 'package:flutter/material.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/academic_session_store.dart';
import 'core/services/class_slot_store.dart';
import 'core/services/course_store.dart';
import 'core/services/task_store.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  initializeAcademicSessionsSync();
  initializeCoursesSync();
  initializeClassSlotsSync();
  initializeTasksSync();
  runApp(const MyApp());
}
