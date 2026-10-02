import 'package:elderly_care_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('accepts a well-formed email', () => expect(Validators.email('rose@example.com'), isNull));
    test('rejects empty', () => expect(Validators.email(''), isNotNull));
    test('rejects missing @', () => expect(Validators.email('rose.example.com'), isNotNull));
  });

  group('Validators.password', () {
    test('accepts a strong password', () => expect(Validators.password('correct-horse-1'), isNull));
    test('rejects short passwords', () => expect(Validators.password('ab1'), isNotNull));
    test('rejects a password with no digit', () => expect(Validators.password('nodigitshere'), isNotNull));
    test('rejects a password with no letter', () => expect(Validators.password('12345678'), isNotNull));
  });

  group('Validators.required', () {
    test('rejects null and blank', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required('   '), isNotNull);
    });
    test('accepts non-blank', () => expect(Validators.required('Rose'), isNull));
  });
}
