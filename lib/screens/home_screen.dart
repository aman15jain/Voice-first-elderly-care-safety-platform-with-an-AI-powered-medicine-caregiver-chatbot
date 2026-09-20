import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:major_project/providers/auth_provider.dart';

/// Placeholder dashboard. Logging out is enough to leave it: the router sees
/// the signed-out state and redirects to the login screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(supabaseServiceProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: profile.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => const Text('Could not load your profile.'),
          data: (user) => Text(
            user == null
                ? 'Dashboard'
                : 'Welcome, ${user.name}\n${user.role.label}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}
