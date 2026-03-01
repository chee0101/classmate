import 'package:flutter/material.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
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
              onPressed: _submit,
              child: const Text('Sign Up'),
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // TODO: Replace mock handler with a real Firebase
      // createUserWithEmailAndPassword call and send email verification
      // to the @student.usm.my address.
      debugPrint('Sign up valid (mock)');

      // navigate to the verify-email info screen.
      Navigator.pushReplacementNamed(context, AppRoutes.verifyEmail);
    }
  }
}
