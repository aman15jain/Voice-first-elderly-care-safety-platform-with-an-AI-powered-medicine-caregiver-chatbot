import 'package:flutter_test/flutter_test.dart';
import 'package:major_project/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts ordinary addresses, ignoring surrounding spaces', () {
      expect(Validators.email('asha@example.com'), isNull);
      expect(Validators.email('  asha.rao+care@mail.example.org  '), isNull);
    });

    test('rejects empty and malformed input', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('asha'), isNotNull);
      expect(Validators.email('asha@'), isNotNull);
      expect(Validators.email('asha@example'), isNotNull);
      expect(Validators.email('as ha@example.com'), isNotNull);
    });
  });

  group('Validators.newPassword', () {
    test('requires the minimum length', () {
      expect(Validators.newPassword(null), isNotNull);
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('12345'), isNotNull);
      expect(Validators.newPassword('123456'), isNull);
    });
  });

  group('Validators.password', () {
    test('only requires that something was entered', () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('x'), isNull);
    });
  });

  group('Validators.name', () {
    test('rejects blank names', () {
      expect(Validators.name(null), isNotNull);
      expect(Validators.name('   '), isNotNull);
      expect(Validators.name('Asha'), isNull);
    });
  });
}
