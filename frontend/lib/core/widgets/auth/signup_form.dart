import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../services/user_profile_store.dart';
import '../../validators/auth_validators.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final usernameFocus = FocusNode();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();
  final confirmPasswordFocus = FocusNode();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    usernameFocus.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();
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
          _label('Username', textTheme),
          _field(
            controller: usernameController,
            focusNode: usernameFocus,
            hint: 'Enter your username',
            validator: (v) =>
                v == null || v.isEmpty ? 'Username is required' : null,
          ),
          _label('Email', textTheme),
          _field(
            controller: emailController,
            focusNode: emailFocus,
            hint: 'Enter your school email',
            validator: validateUsmStudentEmail,
          ),
          _label('Password', textTheme),
          _passwordField(
            controller: passwordController,
            focusNode: passwordFocus,
            hint: 'Enter your password',
            obscure: obscurePassword,
            onToggle: () => setState(() => obscurePassword = !obscurePassword),
            validator: validateStrongPassword,
          ),
          _label('Confirm Password', textTheme),
          _passwordField(
            controller: confirmPasswordController,
            focusNode: confirmPasswordFocus,
            hint: 'Confirm your password',
            obscure: obscureConfirmPassword,
            onToggle: () => setState(
              () => obscureConfirmPassword = !obscureConfirmPassword,
            ),
            validator: (v) =>
                v != passwordController.text ? 'Passwords do not match' : null,
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
                  : const Text('Sign Up'),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------

  Widget _label(String text, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: textTheme.titleLarge),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return _validatedField(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      validator: validator,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return _validatedField(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      obscure: obscure,
      onToggle: onToggle,
      validator: validator,
    );
  }

  Widget _validatedField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    bool obscure = false,
    VoidCallback? onToggle,
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
                suffixIcon: onToggle == null
                    ? null
                    : IconButton(
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
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      await credential.user?.updateDisplayName(usernameController.text.trim());
      final createdUser = credential.user;
      if (createdUser != null) {
        await UserProfileStore.ensureForUser(
          createdUser,
          preferredUsername: usernameController.text.trim(),
        );
      }
      await credential.user?.sendEmailVerification();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.verifyEmail);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'email-already-in-use' => 'This email is already in use.',
        'invalid-email' => 'Please enter a valid email.',
        'weak-password' => 'Password is too weak.',
        _ => e.message ?? 'Sign up failed. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
