import 'package:elderly_care_app/features/auth/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appRoleFromString / appRoleToApiString round-trip', () {
    for (final role in [AppRole.elder, AppRole.caregiver]) {
      expect(appRoleFromString(appRoleToApiString(role)), role);
    }
    expect(appRoleFromString('something-unexpected'), AppRole.admin);
  });

  test('displayName prefers fullName, falls back to the email prefix', () {
    const withName = AppUser(id: '1', email: 'rose@example.com', role: AppRole.elder, preferredLanguage: 'en', fullName: 'Grandma Rose');
    const withoutName = AppUser(id: '2', email: 'rose@example.com', role: AppRole.elder, preferredLanguage: 'en');
    expect(withName.displayName, 'Grandma Rose');
    expect(withoutName.displayName, 'rose');
  });

  test('fromJson defaults preferredLanguage to en when absent', () {
    final user = AppUser.fromJson({'id': '1', 'email': 'rose@example.com', 'role': 'ELDER'});
    expect(user.preferredLanguage, 'en');
    expect(user.role, AppRole.elder);
  });
}
