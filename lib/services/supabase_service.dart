import 'package:major_project/models/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every call the app makes to Supabase goes through this class.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  /// The persisted session, restored by `Supabase.initialize` on app start.
  Session? get currentSession => _client.auth.currentSession;

  /// Emits the initial session first, then every sign-in, sign-out and refresh.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Creates the auth account. The name and role travel as user metadata; a
  /// database trigger (see `supabase/schema.sql`) copies them into the `users`
  /// table, so this works even when email confirmation is switched on.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role.value},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Sends the reset email. [redirectTo] is where the link should land; when
  /// omitted, Supabase uses the project's Site URL.
  Future<void> sendPasswordResetEmail(String email, {String? redirectTo}) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  /// Loads the profile row for [id]. Returns null if there is no such row.
  Future<AppUser?> fetchUser(String id) async {
    final row = await _client.from('users').select().eq('id', id).maybeSingle();
    return row == null ? null : AppUser.fromJson(row);
  }
}
