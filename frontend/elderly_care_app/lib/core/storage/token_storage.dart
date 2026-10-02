import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin seam over the platform keystore/keychain so tests can swap in an in-memory
/// implementation instead of hitting a real secure-storage platform channel.
abstract class SecureStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) => _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// Persists auth tokens in the platform keystore/keychain (never SharedPreferences/plaintext).
/// `isAuthenticated` is a plain [ValueNotifier] rather than Riverpod state so the router
/// (via go_router's `refreshListenable`) and the Dio auth interceptor can both observe it
/// without depending on the Riverpod widget tree.
class TokenStorage {
  TokenStorage(this._store);
  final SecureStore _store;

  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  final ValueNotifier<bool> isAuthenticated = ValueNotifier(false);

  Future<String?> readAccessToken() => _store.read(key: _accessKey);
  Future<String?> readRefreshToken() => _store.read(key: _refreshKey);

  Future<void> save({required String accessToken, required String refreshToken}) async {
    await _store.write(key: _accessKey, value: accessToken);
    await _store.write(key: _refreshKey, value: refreshToken);
    isAuthenticated.value = true;
  }

  Future<void> clear() async {
    await _store.delete(key: _accessKey);
    await _store.delete(key: _refreshKey);
    isAuthenticated.value = false;
  }

  /// Call once at startup, before any network request, so `isAuthenticated` reflects
  /// what's actually on disk rather than its default `false`.
  Future<void> hydrate() async {
    isAuthenticated.value = await readRefreshToken() != null;
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStore(FlutterSecureStorage()));
});
