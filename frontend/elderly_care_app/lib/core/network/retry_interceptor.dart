import 'package:dio/dio.dart';

/// Retries only GET requests (always safe to repeat) that failed for a connectivity reason
/// (no response at all — timeout/connection error), never a request the server actively
/// answered with a 4xx/5xx, and never a non-idempotent method (POST/PATCH/DELETE) — retrying
/// those could duplicate a real action (e.g. marking a dose taken twice).
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2, this.baseDelay = const Duration(milliseconds: 500)});

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isGet = err.requestOptions.method.toUpperCase() == 'GET';
    final isConnectivityIssue = err.response == null;
    final attempt = (err.requestOptions.extra['retryAttempt'] as int?) ?? 0;

    if (!isGet || !isConnectivityIssue || attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(baseDelay * (attempt + 1));
    try {
      final options = err.requestOptions;
      options.extra['retryAttempt'] = attempt + 1;
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(err);
      }
    }
  }
}
