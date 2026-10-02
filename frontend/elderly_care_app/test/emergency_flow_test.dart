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
  testWidgets('tapping Emergency, confirming, shows the active-emergency state with a contact to call', (tester) async {
    final harness = await pumpApp(tester);
    await _loginAsElder(tester);

    await tester.tap(find.text('Emergency'));
    await tester.pumpAndSettle();
    expect(find.text('If you need help right now, press the button below.'), findsOneWidget);

    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Emergency SOS'), findsOneWidget);
    expect(find.textContaining('This will alert your caregivers'), findsOneWidget);

    await tester.tap(find.text('Yes, I need help'));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Active'), findsOneWidget);
    expect(find.text('Daughter Jane'), findsOneWidget);
    expect(find.text("I'm OK Now"), findsOneWidget);
    expect(harness.emergency.lastSosLocation, isNotNull);
  });

  testWidgets('resolving an active emergency returns to the idle SOS button', (tester) async {
    await pumpApp(tester);
    await _loginAsElder(tester);

    await tester.tap(find.text('Emergency'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, I need help'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm OK Now"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm OK"));
    await tester.pumpAndSettle();

    expect(find.text('If you need help right now, press the button below.'), findsOneWidget);
  });

  testWidgets('adding an emergency contact shows it in the list', (tester) async {
    await pumpApp(tester);
    await _loginAsElder(tester);

    await tester.tap(find.text('Emergency'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.contacts));
    await tester.pumpAndSettle();

    expect(find.text('Daughter Jane'), findsOneWidget);

    await tester.tap(find.text('Add Contact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Neighbor Bob');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '555-999-0000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Neighbor Bob'), findsOneWidget);
  });
}
