import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'core/constants/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Fade-out duration
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);

    _startAppSetup();
  }

  void _startAppSetup() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    await _controller.forward();

    if (!mounted) return;
    
    Navigator.of(context).pushReplacementNamed(AppRoutes.authChecker);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 100,
                  width: 100,
                  child: SvgPicture.asset(
                    'assets/images/classmate_logo.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                Text(
                  'ClassMate',
                  style: textTheme.headlineLarge!.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Study. Organize. Succeed.',
                  style: textTheme.bodyLarge!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}