import 'package:dio/dio.dart';
import 'package:elderly_care_app/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/pump_app.dart';

void main() {
  group('logged-out startup begins onboarding at the welcome screen', () {
    Future<void> tapVisible(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('an unauthenticated user lands on the welcome screen, not login', (tester) async {
      await pumpApp(tester, openLogin: false);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.textContaining('Compassionate'), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);
    });

    testWidgets('Sign In opens the existing login screen', (tester) async {
      await pumpApp(tester, openLogin: false);
      await tapVisible(tester, 'Sign In');
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('Skip opens the existing login screen', (tester) async {
      await pumpApp(tester, openLogin: false);
      await tapVisible(tester, 'Skip');
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('Get Started continues to onboarding page 2', (tester) async {
      await pumpApp(tester, openLogin: false);
      await tapVisible(tester, 'Get Started');
      expect(find.bySemanticsLabel('Care Today for a Brighter Tomorrow'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('page 2 Next opens the existing login (onboarding ends), and Back returns to page 2', (tester) async {
      await pumpApp(tester, openLogin: false);
      await tapVisible(tester, 'Get Started');
      await tapVisible(tester, 'Next');
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Almost There'), findsNothing);

      GoRouter.of(tester.element(find.text('Welcome Back'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('the full onboarding path ends in a working login with unchanged role routing', (tester) async {
      await pumpApp(tester, openLogin: false);
      await tapVisible(tester, 'Get Started');
      await tapVisible(tester, 'Next');

      await tester.enterText(find.byType(TextFormField).first, 'elder@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'correct-horse-1');
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Good day, Rose'), findsOneWidget);
    });

    testWidgets('the removed placeholder step is not a route any more', (tester) async {
      await pumpApp(tester, openLogin: false);
      GoRouter.of(tester.element(find.text('Get Started'))).go('/welcome/finish');
      await tester.pumpAndSettle();
      expect(find.text('Almost There'), findsNothing);
      expect(find.text('The last onboarding step is coming soon.'), findsNothing);
    });

    testWidgets('both onboarding pages show exactly two steps', (tester) async {
      await pumpApp(tester, openLogin: false);
      expect(find.bySemanticsLabel('Step 1 of 2'), findsOneWidget);
      await tapVisible(tester, 'Get Started');
      expect(find.bySemanticsLabel('Step 2 of 2'), findsOneWidget);
    });

    testWidgets('page 2 Skip opens the existing login screen', (tester) async {
      await pumpApp(tester, openLogin: false);
      await tapVisible(tester, 'Get Started');
      await tapVisible(tester, 'Skip');
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('a restored elder session skips onboarding and opens elder home', (tester) async {
      await pumpApp(
        tester,
        restoredSession: const AppUser(id: 'u1', email: 'elder@example.com', role: AppRole.elder, preferredLanguage: 'en', fullName: 'Rose'),
      );
      expect(find.textContaining('Good day, Rose'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
    });

    testWidgets('a restored caregiver session skips onboarding and opens the caregiver dashboard', (tester) async {
      await pumpApp(
        tester,
        restoredSession: const AppUser(
          id: 'cg1',
          email: 'caregiver@example.com',
          role: AppRole.caregiver,
          preferredLanguage: 'en',
          fullName: 'Alex',
          notifyOnMissedDose: true,
        ),
      );
      expect(find.text('Elders'), findsOneWidget); // caregiver bottom-nav tab
      expect(find.text('Get Started'), findsNothing);
    });
  });

  testWidgets('a returning user reaches the login screen from the welcome screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('login form shows validation errors instead of submitting empty fields', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email'), findsOneWidget);
  });

  testWidgets('a failed login shows a friendly message, not a raw exception', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.errorToThrow = DioException(
      requestOptions: RequestOptions(path: '/api/auth/login'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        statusCode: 401,
        data: {
          'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid email or password'},
        },
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'elder@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets('a successful login navigates to the elder home screen', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).first, 'elder@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'correct-horse-1');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsNothing);
    expect(find.textContaining('Good day, Rose'), findsOneWidget);
    expect(find.text('All caught up! No medicines due right now.'), findsOneWidget);
  });

  testWidgets('role selection leads to a role-specific registration screen', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Who is this account for?'), findsOneWidget);

    await tester.tap(find.text('I am a Caregiver'));
    await tester.pumpAndSettle();
    expect(find.text('Caregiver Account'), findsOneWidget);
  });
}
