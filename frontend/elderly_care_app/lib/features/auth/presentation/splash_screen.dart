import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../domain/app_user.dart';

/// Shown only while AuthController checks for a stored session.
///
/// Navigation away from here is explicit (`ref.listen` below), not left to the router's
/// declarative `redirect`: the router's `refreshListenable` only fires when
/// `TokenStorage.isAuthenticated` *changes*, but bootstrapping into "no stored session"
/// never changes it (it starts and stays false), so nothing would otherwise tell the
/// router to leave this screen.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      switch (next) {
        case AuthAuthenticated(:final user):
          context.go(user.role == AppRole.caregiver ? '/caregiver' : '/home');
        case AuthUnauthenticated():
          context.go('/login');
        case AuthBootstrapping():
          break;
      }
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('Elderly Care', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
