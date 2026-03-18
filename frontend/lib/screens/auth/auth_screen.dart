import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/widgets/common/animated_segmented_switch.dart';
import '../../core/widgets/auth/login_form.dart';
import '../../core/widgets/auth/signup_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              /// Logo + App name
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 30,
                    width: 30,
                    child: SvgPicture.asset(
                      'assets/images/classmate_logo.svg',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'ClassMate',
                    style: textTheme.headlineLarge?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              /// Login / Sign up toggle
              _buildToggle(context),

              const SizedBox(height: AppSpacing.lg),

              /// Form Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 20,
                      offset: Offset(0, 10),
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: isLogin
                    ? const LoginForm(key: ValueKey('login'))
                    : const SignUpForm(key: ValueKey('signup')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // Toggle UI
  // --------------------------------------------------
  Widget _buildToggle(BuildContext context) {
    return AnimatedSegmentedSwitch<bool>(
      value: isLogin,
      options: const [
        SegmentedSwitchOption<bool>(value: true, label: 'Login'),
        SegmentedSwitchOption<bool>(value: false, label: 'Sign Up'),
      ],
      onChanged: (next) {
        FocusScope.of(context).unfocus();
        setState(() => isLogin = next);
      },
    );
  }
}
