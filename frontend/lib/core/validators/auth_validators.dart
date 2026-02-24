typedef FieldValidator = String? Function(String? value);

/// Email validation for USM student accounts.
///
/// Currently restricted to `@student.usm.my` addresses so the app can
/// focus on the initial target audience. This can be relaxed later if
/// broader support is needed.
final RegExp _usmStudentEmailRegex =
    RegExp(r'^[A-Za-z0-9._%+-]+@student\.usm\.my$');

String? validateUsmStudentEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }

  final email = value.trim();

  if (!_usmStudentEmailRegex.hasMatch(email)) {
    return 'Use your student.usm.my email address';
  }

  return null;
}

/// Strong password validation used for both login and signup.
///
/// Requirements:
/// - At least 8 characters
/// - Includes uppercase, lowercase, number, and special character
String? validateStrongPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }

  final password = value;

  if (password.length < 8) {
    return 'Password must be at least 8 characters';
  }

  final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
  final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
  final hasDigit = RegExp(r'\d').hasMatch(password);
  final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

  if (!hasUppercase || !hasLowercase || !hasDigit || !hasSpecial) {
    return 'Include upper, lower, number, and special character';
  }

  return null;
}

