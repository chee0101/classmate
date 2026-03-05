import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../services/user_profile_store.dart';
import '../../validators/auth_validators.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();

  bool obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('School Email', textTheme),
          _validatedField(
            controller: emailController,
            focusNode: emailFocus,
            hint: 'Enter your school email',
            validator: validateUsmStudentEmail,
          ),
          _fieldLabel('Password', textTheme),
          _validatedPasswordField(
            controller: passwordController,
            focusNode: passwordFocus,
            hint: 'Enter your password',
            obscure: obscurePassword,
            onToggle: () => setState(() => obscurePassword = !obscurePassword),
            validator: validateStrongPassword,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.forgotPassword);
              },
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
                  : const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------
  // Helpers
  // -------------------------

  Widget _fieldLabel(String text, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: textTheme.titleLarge),
    );
  }

  Widget _validatedField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return FormField<String>(
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hint,
                errorText: null,
              ),
              onChanged: state.didChange,
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }

  Widget _validatedPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return FormField<String>(
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              decoration: InputDecoration(
                hintText: hint,
                errorText: null,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: onToggle,
                ),
              ),
              onChanged: state.didChange,
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      final user = credential.user;
      if (user != null) {
        await UserProfileStore.ensureForUser(user);
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.authChecker);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'invalid-credential' => 'Invalid email or password.',
        'user-not-found' => 'No account found for this email.',
        'wrong-password' => 'Invalid email or password.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => e.message ?? 'Login failed. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
