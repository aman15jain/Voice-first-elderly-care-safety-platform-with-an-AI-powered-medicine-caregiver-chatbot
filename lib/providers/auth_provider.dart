import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:major_project/models/app_user.dart';
import 'package:major_project/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService(Supabase.instance.client),
);

/// Follows Supabase auth state changes. Loading only until the first event
/// (the restored session, or none) has arrived.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseServiceProvider).authStateChanges,
);

/// The signed-in user's profile row, or null when signed out.
///
/// Only re-fetches when the user id changes, not on every token refresh.
final appUserProvider = FutureProvider<AppUser?>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.value?.session?.user.id),
  );
  if (userId == null) return null;
  return ref.watch(supabaseServiceProvider).fetchUser(userId);
});
