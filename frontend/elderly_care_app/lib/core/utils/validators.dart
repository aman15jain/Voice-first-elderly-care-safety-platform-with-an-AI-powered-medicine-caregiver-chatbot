/// Client-side checks only mirror the backend's rules closely enough to give fast
/// feedback — the backend (backend/src/modules/auth/auth.validators.ts) is still the
/// source of truth and re-validates everything.
class Validators {
  const Validators._();

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!_emailPattern.hasMatch(v)) return 'Please enter a valid email';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) return 'Password must include a letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Password must include a number';
    return null;
  }

  static String? required(String? value, {String message = 'This field is required'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }
}
