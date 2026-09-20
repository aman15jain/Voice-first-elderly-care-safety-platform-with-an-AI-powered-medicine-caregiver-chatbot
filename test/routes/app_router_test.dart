import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:major_project/providers/onboarding_provider.dart';
import 'package:major_project/routes/app_router.dart';
import 'package:major_project/routes/app_routes.dart';
import 'package:major_project/screens/home_screen.dart';
import 'package:major_project/screens/login_screen.dart';
import 'package:major_project/screens/onboarding_screen.dart';
import 'package:major_project/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase_service.dart';

void main() {
  late FakeSupabaseService service;

  setUp(() => service = FakeSupabaseService());
  tearDown(() => service.dispose());

  testWidgets('stays on the splash screen until the first auth event', (
    tester,
  ) async {
    await pumpApp(tester, service);
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('sends a signed-out user from splash to login', (tester) async {
    await pumpSignedOutApp(tester, service);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('auto-logs in a user whose session was restored', (tester) async {
    await pumpApp(tester, service);
    service.emit(AuthChangeEvent.initialSession, fakeSession());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome, Asha\nCaregiver'), findsOneWidget);
  });

  testWidgets('redirects a signed-out user away from protected routes', (
    tester,
  ) async {
    final container = await pumpSignedOutApp(tester, service);
    final router = container.read(routerProvider);

    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    router.go(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('keeps a signed-in user off the login screen', (tester) async {
    await pumpApp(tester, service);
    service.emit(AuthChangeEvent.initialSession, fakeSession());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container.read(routerProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('logging out returns to the login screen', (tester) async {
    await pumpApp(tester, service);
    service.emit(AuthChangeEvent.initialSession, fakeSession());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    expect(service.signOutCalls, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a session that ends elsewhere also returns to login', (
    tester,
  ) async {
    await pumpApp(tester, service);
    service.emit(AuthChangeEvent.initialSession, fakeSession());
    await tester.pumpAndSettle();

    service.emit(AuthChangeEvent.signedOut, null);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a token refresh leaves the current screen alone', (
    tester,
  ) async {
    await pumpApp(tester, service);
    service.emit(AuthChangeEvent.initialSession, fakeSession());
    await tester.pumpAndSettle();

    service.emit(AuthChangeEvent.tokenRefreshed, fakeSession());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('sends a user with pending onboarding there, then to home', (
    tester,
  ) async {
    final container = await pumpApp(tester, service);
    container.read(onboardingPendingProvider.notifier).set(true);
    service.emit(AuthChangeEvent.initialSession, fakeSession());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(onboardingPendingProvider), isFalse);
    // The router really is the go_router instance the app uses.
    expect(container.read(routerProvider), isA<GoRouter>());
  });
}
