import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

Future<void> _loginAsElder(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'elder@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'correct-horse-1');
  await tester.tap(find.text('Log In'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Play Game shows the four built-in games and starting one shows its difficulty picker', (tester) async {
    await pumpApp(tester);
    await _loginAsElder(tester);

    await tester.tap(find.text('Play Game'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Match'), findsOneWidget);
    expect(find.text('Pattern Recognition'), findsOneWidget);
    expect(find.text('Attention Exercise'), findsOneWidget);
    expect(find.text('Sequence Recall'), findsOneWidget);

    await tester.tap(find.text('Memory Match'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a difficulty'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('This week’s activity screen shows the weekly summary', (tester) async {
    final harness = await pumpApp(tester);
    harness.activity.daysToReturn = const [];
    await _loginAsElder(tester);

    await tester.tap(find.text('See this week’s activity'));
    await tester.pumpAndSettle();

    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('0 of 0'), findsOneWidget);
  });

  testWidgets('the elder home screen pings app-opened once', (tester) async {
    final harness = await pumpApp(tester);
    await _loginAsElder(tester);
    expect(harness.activity.appOpenedCalled, isTrue);
  });
}
