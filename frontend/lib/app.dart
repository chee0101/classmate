import 'package:classmate/screens/auth/auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/routes.dart';
import 'core/layout/main_scaffold.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/add/add_new_screen.dart' show AddNewScreen, AddType;
import 'screens/extract/review_extracted_calendar_screen.dart';
import 'screens/task/task_detail_screen.dart';
import 'screens/profile/academic_sessions_screen.dart';
import 'screens/profile/courses_screen.dart';
import 'screens/profile/timetables_screen.dart';
import 'screens/extract/auto_extract_screen.dart';
import 'core/models/task.dart';
import 'splash_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClassMate',
      debugShowCheckedModeBanner: false,

      // ===================================================
      // 1. GLOBAL THEME
      // ===================================================
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: appPrimarySwatch,
          brightness: Brightness.light,
          primary: appPrimarySwatch.shade700,
          surface: appPrimarySwatch.shade50,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: appPrimarySwatch.shade50,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        scaffoldBackgroundColor: appPrimarySwatch.shade50,
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          /// App title / splash title
          headlineLarge: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),

          /// Screen title
          headlineMedium: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),

          /// Section title (Cards, lists)
          titleLarge: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          
          titleMedium: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),

          titleSmall: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),

          /// Body text
          bodyLarge: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),

          /// Secondary body text
          bodyMedium: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),

          /// Caption / helper text
          bodySmall: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),

          /// Button text
          labelLarge: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          contentTextStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: appPrimarySwatch.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),

          /// Input text style
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade400,
          ),

          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),

          errorStyle: GoogleFonts.poppins(
            fontSize: 12,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: appPrimarySwatch.shade700),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
            labelStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: appPrimarySwatch.shade700),
            ),
          ),
          menuStyle: const MenuStyle(
            backgroundColor: WidgetStatePropertyAll<Color>(Colors.white),
          ),
        ),
        menuButtonTheme: MenuButtonThemeData(
          style: ButtonStyle(
            textStyle: WidgetStatePropertyAll<TextStyle?>(
              GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),

      // ===================================================
      // 2. ROUTING
      // ===================================================
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.authChecker: (context) => const AuthChecker(),
        AppRoutes.login: (context) => const AuthScreen(),
        AppRoutes.verifyEmail: (context) => const VerifyEmailScreen(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
        AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
        AppRoutes.addNew: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final initialType = args is AddType ? args : null;
          return AddNewScreen(initialType: initialType);
        },
        AppRoutes.autoExtract: (context) => const AutoExtractScreen(),
        AppRoutes.reviewExtractedCalendar: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final jsonStr = args is String ? args : '';
          return ReviewExtractedCalendarScreen(responseJson: jsonStr);
        },
        AppRoutes.taskDetail: (context) {
          final task = ModalRoute.of(context)!.settings.arguments as Task;
          return TaskDetailScreen(task: task);
        },
        AppRoutes.academicSessions: (context) =>
            const AcademicSessionsScreen(),
        AppRoutes.courses: (context) => const CoursesScreen(),
        AppRoutes.timetables: (context) => const TimetablesScreen(),
      },
    );
  }
}

/// ===================================================
/// AuthChecker
/// Decides whether user goes to MainScaffold or Auth flow
/// ===================================================
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const AuthScreen();
        if (!user.emailVerified) return const VerifyEmailScreen();
        return const MainScaffold();
      },
    );
  }
}

// ----------------------------------------------------
// Dummy/Placeholder Screens for compilation purposes
// ----------------------------------------------------

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Your Main App Content')),
    );
  }
}
