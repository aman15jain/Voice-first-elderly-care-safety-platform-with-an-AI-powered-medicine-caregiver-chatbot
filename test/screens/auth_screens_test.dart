import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:major_project/models/app_user.dart';
import 'package:major_project/screens/forgot_password_screen.dart';
import 'package:major_project/screens/home_screen.dart';
import 'package:major_project/screens/login_screen.dart';
import 'package:major_project/screens/onboarding_screen.dart';
import 'package:major_project/screens/signup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase_service.dart';

Finder _field(String label) => find.widgetWithText(TextFormField, label);
Finder _button(String label) => find.widgetWithText(FilledButton, label);

void main() {
  late FakeSupabaseService service;

  setUp(() => service = FakeSupabaseService());
  tearDown(() => service.dispose());

  group('login', () {
    testWidgets('shows validation errors for empty fields', (tester) async {
      await pumpSignedOutApp(tester, service);

      await tester.tap(_button('Log in'));
      await tester.pump();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('rejects a malformed email', (tester) async {
      await pumpSignedOutApp(tester, service);

      await tester.enterText(_field('Email'), 'not-an-email');
      await tester.tap(_button('Log in'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('valid credentials lead to home', (tester) async {
      await pumpSignedOutApp(tester, service);

      await tester.enterText(_field('Email'), 'asha@example.com');
      await tester.enterText(_field('Password'), 'secret123');
      await tester.tap(_button('Log in'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('shows the error message and stays on the screen', (
      tester,
    ) async {
      service.signInError = const AuthException('Invalid login credentials');
      await pumpSignedOutApp(tester, service);

      await tester.enterText(_field('Email'), 'asha@example.com');
      await tester.enterText(_field('Password'), 'wrong-password');
      await tester.tap(_button('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid login credentials'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      // The button is usable again after the failure.
      expect(
        tester.widget<FilledButton>(_button('Log in')).onPressed,
        isNotNull,
      );
    });
  });

  group('signup', () {
    Future<void> openSignup(WidgetTester tester) async {
      await pumpSignedOutApp(tester, service);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupScreen), findsOneWidget);
    }

    Future<void> fillDetails(WidgetTester tester) async {
      await tester.enterText(_field('Name'), 'Asha Rao');
      await tester.enterText(_field('Email'), 'asha@example.com');
      await tester.enterText(_field('Password'), 'secret123');
    }

    testWidgets('requires a role to be chosen', (tester) async {
      await openSignup(tester);
      await fillDetails(tester);

      await tester.tap(_button('Create account'));
      await tester.pump();

      expect(find.text('Please choose a role'), findsOneWidget);
      expect(service.lastSignUp, isNull);
    });

    testWidgets('enforces the minimum password length', (tester) async {
      await openSignup(tester);
      await tester.enterText(_field('Password'), '123');

      await tester.tap(_button('Create account'));
      await tester.pump();

      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(service.lastSignUp, isNull);
    });

    testWidgets('sends the chosen role and lands on onboarding', (
      tester,
    ) async {
      await openSignup(tester);
      await fillDetails(tester);
      await tester.tap(find.text('Caregiver'));
      await tester.pump();

      await tester.tap(_button('Create account'));
      await tester.pumpAndSettle();

      expect(service.lastSignUp?.role, UserRole.caregiver);
      expect(service.lastSignUp?.name, 'Asha Rao');
      expect(service.lastSignUp?.email, 'asha@example.com');
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('the elderly role is sent when that one is chosen', (
      tester,
    ) async {
      await openSignup(tester);
      await fillDetails(tester);
      await tester.tap(find.text('Elderly User'));
      await tester.pump();

      await tester.tap(_button('Create account'));
      await tester.pumpAndSettle();

      expect(service.lastSignUp?.role, UserRole.elderly);
    });

    testWidgets(
      'asks the user to confirm their email when there is no session',
      (tester) async {
        service.requireEmailConfirmation = true;
        await openSignup(tester);
        await fillDetails(tester);
        await tester.tap(find.text('Elderly User'));
        await tester.pump();

        await tester.tap(_button('Create account'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Check your email'), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });

  group('forgot password', () {
    testWidgets('sends the reset email and returns to login', (tester) async {
      await pumpSignedOutApp(tester, service);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);

      await tester.enterText(_field('Email'), 'asha@example.com');
      await tester.tap(_button('Send reset link'));
      await tester.pumpAndSettle();

      expect(service.lastResetEmail, 'asha@example.com');
      expect(find.textContaining('a reset link is on its way'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('validates the email first', (tester) async {
      await pumpSignedOutApp(tester, service);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      await tester.tap(_button('Send reset link'));
      await tester.pump();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(service.lastResetEmail, isNull);
    });
  });
}
