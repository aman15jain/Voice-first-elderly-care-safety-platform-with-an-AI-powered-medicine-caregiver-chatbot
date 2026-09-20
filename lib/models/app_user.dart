/// The role a user picks at signup. [value] is what `users.role` stores.
enum UserRole {
  elderly('elderly', 'Elderly User'),
  caregiver('caregiver', 'Caregiver');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => throw ArgumentError.value(value, 'value', 'Unknown role'),
    );
  }
}

/// A row of the `users` table (the app profile, not the Supabase auth user).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.languagePref,
    required this.createdAt,
    this.phone,
  });

  final String id;
  final String name;
  final UserRole role;
  final String? phone;
  final String languagePref;
  final DateTime createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      role: UserRole.fromValue(json['role'] as String),
      phone: json['phone'] as String?,
      languagePref: json['language_pref'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
