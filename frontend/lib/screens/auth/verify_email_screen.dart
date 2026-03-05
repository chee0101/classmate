import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      if (refreshed != null && refreshed.emailVerified) {
        Navigator.pushReplacementNamed(context, AppRoutes.authChecker);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified yet.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _resending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to resend verification.')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final email = FirebaseAuth.instance.currentUser?.email ?? '@student.usm.my';

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
              'We\'ve sent a verification link to $email. '
              'Open the email and tap the link to activate your account.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checking ? null : _checkVerification,
                child: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('I\'ve verified my email'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: _resending ? null : _resendVerification,
                child: Text(
                  _resending ? 'Sending...' : 'Resend verification email',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

