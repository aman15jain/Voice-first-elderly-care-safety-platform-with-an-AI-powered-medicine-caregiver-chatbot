/// Form field validators. Each returns an error message, or null when valid.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Matches Supabase's default minimum password length.
  static const minPasswordLength = 6;

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your name';
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  /// For logging in: only checks that something was entered.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  /// For choosing a password at signup.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Choose a password';
    if (value.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    return null;
  }
}
