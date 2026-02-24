import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_spacing.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width:
                  (MediaQuery.of(context).size.width - 2 * AppSpacing.lg - 8) /
                      2,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              _toggleText(
                context,
                text: 'Login',
                active: isLogin,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => isLogin = true);
                },
              ),
              _toggleText(
                context,
                text: 'Sign Up',
                active: !isLogin,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => isLogin = false);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleText(
    BuildContext context, {
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Text(
            text,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: active
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}
