import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('an unauthenticated user lands on the login screen', (tester) async {
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
        data: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid email or password'}},
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
