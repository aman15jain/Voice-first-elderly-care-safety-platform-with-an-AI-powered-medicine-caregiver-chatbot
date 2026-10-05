import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._authDio, this._apiDio, this._tokenStorage);

  /// No interceptor: register/login/refresh/logout are public endpoints.
  final Dio _authDio;

  /// Has the auth interceptor: used for GET /api/users/me.
  final Dio _apiDio;
  final TokenStorage _tokenStorage;

  Future<void> register({required String email, required String password, required AppRole role, required String fullName}) async {
    final res = await _authDio.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {'email': email, 'password': password, 'role': appRoleToApiString(role), 'fullName': fullName},
    );
    await _saveSession(res.data!);
  }

  Future<void> login({required String email, required String password}) async {
    final res = await _authDio.post<Map<String, dynamic>>('/api/auth/login', data: {'email': email, 'password': password});
    await _saveSession(res.data!);
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _authDio.post<void>('/api/auth/logout', data: {'refreshToken': refreshToken});
      } catch (_) {
        // Best-effort: tokens are cleared locally regardless.
      }
    }
    await _tokenStorage.clear();
  }

  Future<AppUser> fetchProfile() async {
    final res = await _apiDio.get<Map<String, dynamic>>('/api/users/me');
    return AppUser.fromJson(res.data!);
  }

  /// Caregiver-only. Returns the saved value so the caller doesn't need a second round-trip.
  Future<bool> updateNotificationPreferences({required bool notifyOnMissedDose}) async {
    final res = await _apiDio.patch<Map<String, dynamic>>('/api/users/me/notification-preferences', data: {'notifyOnMissedDose': notifyOnMissedDose});
    return res.data!['notifyOnMissedDose'] as bool;
  }

  Future<void> _saveSession(Map<String, dynamic> body) =>
      _tokenStorage.save(accessToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authDioProvider), ref.watch(dioProvider), ref.watch(tokenStorageProvider));
});
