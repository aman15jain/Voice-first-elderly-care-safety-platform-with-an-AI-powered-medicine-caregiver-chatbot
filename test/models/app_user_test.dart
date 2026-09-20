import 'package:flutter_test/flutter_test.dart';
import 'package:major_project/models/app_user.dart';

void main() {
  group('UserRole', () {
    test('values match what the users table stores', () {
      expect(UserRole.elderly.value, 'elderly');
      expect(UserRole.caregiver.value, 'caregiver');
    });

    test('labels are what the signup screen shows', () {
      expect(UserRole.elderly.label, 'Elderly User');
      expect(UserRole.caregiver.label, 'Caregiver');
    });

    test('fromValue round-trips every role', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromValue(role.value), role);
      }
    });

    test('fromValue rejects anything else', () {
      expect(() => UserRole.fromValue('admin'), throwsArgumentError);
    });
  });

  group('AppUser.fromJson', () {
    test('parses a users row', () {
      final user = AppUser.fromJson({
        'id': '7f9b3c1e-0000-0000-0000-000000000001',
        'name': 'Asha Rao',
        'role': 'caregiver',
        'phone': '+911234567890',
        'language_pref': 'hi',
        'created_at': '2026-09-21T10:30:00+00:00',
      });

      expect(user.id, '7f9b3c1e-0000-0000-0000-000000000001');
      expect(user.name, 'Asha Rao');
      expect(user.role, UserRole.caregiver);
      expect(user.phone, '+911234567890');
      expect(user.languagePref, 'hi');
      expect(user.createdAt, DateTime.utc(2026, 9, 21, 10, 30));
    });

    test('allows a missing phone number', () {
      final user = AppUser.fromJson({
        'id': 'abc',
        'name': 'Asha',
        'role': 'elderly',
        'phone': null,
        'language_pref': 'en',
        'created_at': '2026-09-21T10:30:00+00:00',
      });

      expect(user.phone, isNull);
    });
  });
}
