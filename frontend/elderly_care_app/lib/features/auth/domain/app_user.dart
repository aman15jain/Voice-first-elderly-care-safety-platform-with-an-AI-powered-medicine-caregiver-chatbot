enum AppRole { elder, caregiver, admin }

AppRole appRoleFromString(String value) {
  switch (value) {
    case 'ELDER':
      return AppRole.elder;
    case 'CAREGIVER':
      return AppRole.caregiver;
    default:
      return AppRole.admin;
  }
}

String appRoleToApiString(AppRole role) {
  switch (role) {
    case AppRole.elder:
      return 'ELDER';
    case AppRole.caregiver:
      return 'CAREGIVER';
    case AppRole.admin:
      return 'ADMIN';
  }
}

class AppUser {
  const AppUser({required this.id, required this.email, required this.role, required this.preferredLanguage, this.fullName, this.notifyOnMissedDose});

  final String id;
  final String email;
  final AppRole role;
  final String preferredLanguage;
  final String? fullName;

  /// Only meaningful for a caregiver account; null for an elder/admin.
  final bool? notifyOnMissedDose;

  /// A short, friendly display name — falls back to the part of the email before '@'.
  String get displayName => fullName?.trim().isNotEmpty == true ? fullName! : email.split('@').first;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String,
    role: appRoleFromString(json['role'] as String),
    preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
    fullName: json['fullName'] as String?,
    notifyOnMissedDose: json['notifyOnMissedDose'] as bool?,
  );
}
