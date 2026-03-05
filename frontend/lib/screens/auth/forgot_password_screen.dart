import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/validators/auth_validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final emailFocus = FocusNode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    emailController.dispose();
    emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forgot your password?',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Enter your @student.usm.my email and we\'ll send you a '
                'password reset link.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'School Email',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: emailController,
                focusNode: emailFocus,
                validator: validateUsmStudentEmail,
                decoration: const InputDecoration(
                  hintText: 'Enter your school email',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send reset link'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.login,
                    );
                  },
                  child: const Text('Back to login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to send reset link.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

