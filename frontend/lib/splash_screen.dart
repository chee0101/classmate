import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'core/constants/routes.dart';
import 'core/services/app_bootstrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  final _bootstrapper = AppBootstrapper.instance;

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
    final startedAt = DateTime.now();

    // Ensure first frame is rendered before boot work starts.
    _bootstrapper.startAfterFirstFrame();

    // Wait until bootstrap reports completion (progress reaches 1.0).
    while (mounted && _bootstrapper.progress.value < 1.0) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    final elapsed = DateTime.now().difference(startedAt);
    const minSplashDuration = Duration(milliseconds: 100);
    final remaining = minSplashDuration - elapsed;
    if (remaining.inMilliseconds > 0) {
      await Future.delayed(remaining);
    }
    
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
                const SizedBox(height: 20),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: ValueListenableBuilder<double>(
                      valueListenable: _bootstrapper.progress,
                      builder: (context, progress, _) {
                        return LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: colorScheme.primary,
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.18,
                          ),
                        );
                      },
                    ),
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