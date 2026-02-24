import 'package:flutter/material.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
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
              onPressed: _submit,
              child: const Text('Login'),
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // TODO: Replace this mock handler with a real Firebase
      // signInWithEmailAndPassword call and token handling.
      debugPrint('Login valid (mock)');

      // navigate to the auth checker
      Navigator.pushReplacementNamed(context, AppRoutes.authChecker);
    }
  }
}
