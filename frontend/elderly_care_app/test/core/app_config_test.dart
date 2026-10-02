import 'package:elderly_care_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the explicit override when provided, regardless of platform or build mode', () {
    expect(
      AppConfig.resolveApiBaseUrl(override: 'https://api.example.com', isReleaseMode: true, isAndroid: false),
      'https://api.example.com',
    );
  });

  test('falls back to the Android emulator host alias in debug/profile mode', () {
    expect(AppConfig.resolveApiBaseUrl(override: '', isReleaseMode: false, isAndroid: true), 'http://10.0.2.2:4000');
  });

  test('falls back to localhost on non-Android in debug/profile mode', () {
    expect(AppConfig.resolveApiBaseUrl(override: '', isReleaseMode: false, isAndroid: false), 'http://localhost:4000');
  });

  test('a release build with no override fails loudly instead of silently using a dev URL', () {
    expect(
      () => AppConfig.resolveApiBaseUrl(override: '', isReleaseMode: true, isAndroid: false),
      throwsA(isA<StateError>()),
    );
  });
}
