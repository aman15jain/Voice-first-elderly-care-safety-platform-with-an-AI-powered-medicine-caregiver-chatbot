import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:major_project/providers/auth_provider.dart';
import 'package:major_project/providers/onboarding_provider.dart';
import 'package:major_project/routes/app_routes.dart';
import 'package:major_project/screens/forgot_password_screen.dart';
import 'package:major_project/screens/home_screen.dart';
import 'package:major_project/screens/login_screen.dart';
import 'package:major_project/screens/onboarding_screen.dart';
import 'package:major_project/screens/signup_screen.dart';
import 'package:major_project/screens/splash_screen.dart';

/// Routes a signed-out user may visit. Everything else requires a session.
const _publicRoutes = {
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.forgotPassword,
};

final routerProvider = Provider<GoRouter>((ref) {
  // The router is created once. Auth and onboarding changes poke this notifier
  // so go_router re-runs `redirect`, instead of rebuilding the router.
  final refresh = ValueNotifier<int>(0);
  void poke() => refresh.value++;
  ref.listen(authStateProvider, (_, _) => poke());
  ref.listen(onboardingPendingProvider, (_, _) => poke());

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    // Stay on the splash screen until Supabase reports the initial session.
    if (ref.read(authStateProvider).isLoading) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final signedIn = ref.read(supabaseServiceProvider).currentSession != null;
    final onPublicRoute = _publicRoutes.contains(location);

    if (!signedIn) return onPublicRoute ? null : AppRoutes.login;

    if (onPublicRoute || location == AppRoutes.splash) {
      final needsOnboarding = ref.read(onboardingPendingProvider);
      return needsOnboarding ? AppRoutes.onboarding : AppRoutes.home;
    }
    return null;
  }

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
