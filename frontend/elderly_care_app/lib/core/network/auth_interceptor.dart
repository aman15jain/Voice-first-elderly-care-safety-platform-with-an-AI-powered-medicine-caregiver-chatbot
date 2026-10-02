import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the access token to every request and, on a 401, refreshes it once and
/// retries the original request. Concurrent 401s share a single refresh call. If the
/// refresh itself fails, tokens are cleared — [TokenStorage.isAuthenticated] flips to
/// false and the router (via `refreshListenable`) sends the user back to login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, this._baseUrl);

  final TokenStorage _tokenStorage;
  final String _baseUrl;
  Completer<bool>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.readAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthEndpoint = err.requestOptions.path.startsWith('/api/auth/');
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (err.response?.statusCode != 401 || isAuthEndpoint || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      handler.next(err);
      return;
    }

    try {
      final newToken = await _tokenStorage.readAccessToken();
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';
      retryOptions.extra['retried'] = true;
      final response = await Dio(BaseOptions(baseUrl: _baseUrl)).fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<bool> _refresh() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshing = completer;
    _doRefresh().then((ok) {
      completer.complete(ok);
      _refreshing = null;
    });
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken == null) {
        await _tokenStorage.clear();
        return false;
      }
      final res = await Dio(BaseOptions(baseUrl: _baseUrl)).post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final body = res.data!;
      await _tokenStorage.save(accessToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String);
      return true;
    } catch (_) {
      await _tokenStorage.clear();
      return false;
    }
  }
}
