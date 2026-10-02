import 'package:dio/dio.dart';

/// A user-facing failure. Screens show [message] directly and never a raw exception —
/// see docs/api.md: the backend's own error messages are already elder-friendly for 4xx
/// responses, so those are passed through; anything else (network errors, 5xx) gets a
/// generic message instead of leaking technical detail.
class AppFailure {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  static const _generic = AppFailure('Sorry, we could not complete that. Please try again.');
  static const _networkUnreachable = AppFailure(
    'Could not reach the server. Please check your connection and try again.',
    code: 'NETWORK_UNREACHABLE',
  );

  /// True for a request that never got a response at all (no connectivity, DNS failure,
  /// timeout) — distinct from a request the server actively rejected (4xx/5xx). Screens with
  /// a network-dependent safety action (e.g. Emergency SOS) use this to tell the user plainly
  /// that delivery could not be confirmed, rather than a generic "please try again".
  static bool isNetworkError(Object error) => error is DioException && error.response == null;

  factory AppFailure.fromError(Object error) {
    if (error is DioException) {
      if (error.response == null) return _networkUnreachable;

      final status = error.response?.statusCode;
      final data = error.response?.data;
      final errorBody = (data is Map) ? data['error'] : null;
      final serverMessage = (errorBody is Map) ? errorBody['message'] as String? : null;

      if (status != null && status < 500 && serverMessage != null) {
        return AppFailure(serverMessage, code: errorBody['code'] as String?);
      }
      return _generic;
    }
    return _generic;
  }
}
