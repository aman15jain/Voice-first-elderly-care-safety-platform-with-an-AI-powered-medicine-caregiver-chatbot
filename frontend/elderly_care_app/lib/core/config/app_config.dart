import 'package:flutter/foundation.dart';

/// Build-time configuration. Override with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
/// Only the Node backend URL lives here. No DB credentials or LLM keys, ever.
class AppConfig {
  const AppConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl =>
      resolveApiBaseUrl(override: _override, isReleaseMode: kReleaseMode, isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Exposed for testing the release-mode guard below without needing an actual release build.
  @visibleForTesting
  static String resolveApiBaseUrl({required String override, required bool isReleaseMode, required bool isAndroid}) {
    if (override.isNotEmpty) return override;
    if (isReleaseMode) {
      // A release build with no explicit API_BASE_URL would otherwise silently fall back to a
      // development URL (localhost/10.0.2.2) — a release build pointed at nothing real, shipped
      // by accident. Fail loudly at startup instead; see docs/setup.md#flutter-release-builds.
      throw StateError(
        'API_BASE_URL was not set for this release build. Build with '
        '--dart-define=API_BASE_URL=https://your-production-api.example.com',
      );
    }
    // The Android emulator reaches the host machine at 10.0.2.2.
    if (isAndroid) return 'http://10.0.2.2:4000';
    return 'http://localhost:4000';
  }
}
