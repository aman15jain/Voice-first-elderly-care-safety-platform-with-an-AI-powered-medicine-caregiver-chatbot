import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:major_project/app.dart';
import 'package:major_project/models/app_user.dart';
import 'package:major_project/providers/auth_provider.dart';
import 'package:major_project/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session fakeSession({String userId = 'user-1'}) {
  return Session(
    accessToken: 'access-token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );
}

/// An in-memory stand-in for [SupabaseService]. Tests drive it by calling
/// [emit], the way Supabase pushes auth events to the real service.
class FakeSupabaseService implements SupabaseService {
  final _controller = StreamController<AuthState>.broadcast();
  Session? _session;

  /// What [fetchUser] returns.
  AppUser? profile = AppUser(
    id: 'user-1',
    name: 'Asha',
    role: UserRole.caregiver,
    languagePref: 'en',
    createdAt: DateTime.utc(2026),
  );

  /// Make [signIn] throw this instead of signing in.
  Object? signInError;

  /// Make [signUp] behave as if the project requires email confirmation:
  /// the account is created but no session is returned.
  bool requireEmailConfirmation = false;

  ({String email, String name, UserRole role})? lastSignUp;
  String? lastResetEmail;
  int signOutCalls = 0;

  void emit(AuthChangeEvent event, Session? session) {
    _session = session;
    _controller.add(AuthState(event, session));
  }

  Future<void> dispose() => _controller.close();

  @override
  Session? get currentSession => _session;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    lastSignUp = (email: email, name: name, role: role);
    final session = fakeSession();
    if (requireEmailConfirmation) {
      return AuthResponse(user: session.user);
    }
    emit(AuthChangeEvent.signedIn, session);
    return AuthResponse(session: session, user: session.user);
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    final session = fakeSession();
    emit(AuthChangeEvent.signedIn, session);
    return AuthResponse(session: session, user: session.user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(AuthChangeEvent.signedOut, null);
  }

  @override
  Future<void> sendPasswordResetEmail(
    String email, {
    String? redirectTo,
  }) async {
    lastResetEmail = email;
  }

  @override
  Future<AppUser?> fetchUser(String id) async => profile;
}

/// Starts the real [App] on top of [service]. It sits on the splash screen
/// until the test calls `service.emit(AuthChangeEvent.initialSession, ...)`.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeSupabaseService service,
) async {
  // Tall enough that the signup form fits without scrolling.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [supabaseServiceProvider.overrideWithValue(service)],
      retry: (retryCount, error) => null,
      child: const App(),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(App)));
}

/// [pumpApp], then reports "no saved session" and waits for the login screen.
Future<ProviderContainer> pumpSignedOutApp(
  WidgetTester tester,
  FakeSupabaseService service,
) async {
  final container = await pumpApp(tester, service);
  service.emit(AuthChangeEvent.initialSession, null);
  await tester.pumpAndSettle();
  return container;
}
