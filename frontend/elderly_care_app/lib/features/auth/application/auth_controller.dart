import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

sealed class AuthState {
  const AuthState();
}

/// Checking for a stored session at app start. The splash screen is shown for this.
class AuthBootstrapping extends AuthState {
  const AuthBootstrapping();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AppUser user;
}

/// The single source of truth for "who is signed in". Screens call [login]/[register]/
/// [logout] and await them; the router's `redirect` reads [state] to decide where the
/// user is allowed to be. See core/router/app_router.dart.
class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repo;
  late final TokenStorage _tokenStorage;

  @override
  AuthState build() {
    _repo = ref.watch(authRepositoryProvider);
    _tokenStorage = ref.watch(tokenStorageProvider);
    unawaited(_bootstrap());
    return const AuthBootstrapping();
  }

  Future<void> _bootstrap() async {
    await _tokenStorage.hydrate();
    if (!_tokenStorage.isAuthenticated.value) {
      state = const AuthUnauthenticated();
      return;
    }
    try {
      final user = await _repo.fetchProfile();
      state = AuthAuthenticated(user);
    } catch (_) {
      // Stored refresh token is gone/invalid server-side; start fresh.
      await _tokenStorage.clear();
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _repo.login(email: email, password: password);
    state = AuthAuthenticated(await _repo.fetchProfile());
  }

  Future<void> register({required String email, required String password, required AppRole role, required String fullName}) async {
    await _repo.register(email: email, password: password, role: role, fullName: fullName);
    state = AuthAuthenticated(await _repo.fetchProfile());
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  /// Re-fetches the profile after a change made elsewhere (e.g. notification preferences)
  /// so every screen reading [authControllerProvider] sees the new value immediately.
  Future<void> refreshProfile() async {
    state = AuthAuthenticated(await _repo.fetchProfile());
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
