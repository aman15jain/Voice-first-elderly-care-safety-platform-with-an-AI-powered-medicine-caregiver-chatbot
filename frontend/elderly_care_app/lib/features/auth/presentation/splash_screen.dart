import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/care/care_connect_logo.dart';
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
        // Logged-out users start onboarding; its Skip / Sign In lead to /login. The role is
        // unknown until sign-in, so this is the single entry point for everyone signed out.
        case AuthUnauthenticated():
          context.go('/welcome');
        case AuthBootstrapping():
          break;
      }
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CareConnectMark(size: 80),
            const SizedBox(height: CareSpacing.lg),
            Text(CareConnectLogo.brandName, style: CareText.brandName.copyWith(fontSize: 40, color: CareColors.primary)),
            const SizedBox(height: CareSpacing.xs),
            const Text('Care Today for a Brighter Tomorrow', style: CareText.tagline),
            const SizedBox(height: CareSpacing.xxl),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}
