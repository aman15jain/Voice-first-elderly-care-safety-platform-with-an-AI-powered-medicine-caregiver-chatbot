import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';

const _connectTimeout = Duration(seconds: 6);
const _receiveTimeout = Duration(seconds: 10);

/// Bare HTTP client for the public auth endpoints (register/login/refresh/logout).
/// No interceptor: these calls never need — and must not wait on — an access token.
final authDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {'Accept': 'application/json'},
    ),
  );
});

/// HTTP client for every authenticated endpoint. Attaches the access token and
/// transparently refreshes it once on a 401 (see AuthInterceptor).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(AuthInterceptor(ref.watch(tokenStorageProvider), AppConfig.apiBaseUrl));
  // Must come after AuthInterceptor so a retried request still carries a refreshed token.
  dio.interceptors.add(RetryInterceptor(dio));
  return dio;
});
