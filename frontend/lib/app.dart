import 'package:classmate/screens/auth/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/routes.dart';
import 'core/layout/main_scaffold.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/task/task_detail_screen.dart';
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
          seedColor: AppPrimarySwatch,
          brightness: Brightness.light,
          primary: AppPrimarySwatch.shade700,
          surface: AppPrimarySwatch.shade50,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppPrimarySwatch.shade50,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        scaffoldBackgroundColor: AppPrimarySwatch.shade50,
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          /// App title / splash title
          headlineLarge: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),

          /// Screen title
          headlineMedium: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),

          /// Section title (Cards, lists)
          titleLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),

          /// Body text
          bodyLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),

          /// Secondary body text
          bodyMedium: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),

          /// Caption / helper text
          bodySmall: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),

          /// Button text
          labelLarge: const TextStyle(
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
            backgroundColor: AppPrimarySwatch.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
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
          hintStyle: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade400,
          ),

          labelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),

          errorStyle: const TextStyle(
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
            borderSide: BorderSide(color: AppPrimarySwatch.shade700),
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
        AppRoutes.taskDetail: (context) {
          final task = ModalRoute.of(context)!.settings.arguments as Task;
          return TaskDetailScreen(task: task);
        },
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
    // TODO: Replace with real auth check (SharedPreferences / token)
    final bool userIsLoggedIn = true;

    if (userIsLoggedIn) {
      return const MainScaffold();
    } else {
      return const AuthScreen();
    }
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
