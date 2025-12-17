import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/routes.dart';
import 'core/layout/main_scaffold.dart';
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

        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPrimarySwatch.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
        AppRoutes.welcome: (context) => const WelcomeScreen(),
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
      return const WelcomeScreen();
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
