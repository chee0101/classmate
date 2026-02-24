import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check your student email',
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We\'ve sent a verification link to your @student.usm.my email. '
              'Open the email and tap the link to activate your account.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Replace this mock navigation with a real Firebase
                  // emailVerified check and token-based auth flow.
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.authChecker,
                  );
                },
                child: const Text('I\'ve verified my email'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: Implement resend verification email via Firebase.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Resend verification (mock only).'),
                    ),
                  );
                },
                child: const Text('Resend verification email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

