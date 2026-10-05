import 'package:elderly_care_app/features/auth/domain/app_user.dart';
import 'package:elderly_care_app/features/dashboard/domain/elder_dashboard_row.dart';
import 'package:elderly_care_app/features/medicines/domain/medicine_models.dart';
import 'package:elderly_care_app/features/notifications/domain/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

const _caregiver = AppUser(
  id: 'cg1',
  email: 'caregiver@example.com',
  role: AppRole.caregiver,
  preferredLanguage: 'en',
  fullName: 'Alex',
  notifyOnMissedDose: true,
);

ElderDashboardRow _row({required String elderId, required String name, int? takenRate, bool activeEmergency = false}) {
  return ElderDashboardRow(
    elderId: elderId,
    elderName: name,
    elderEmail: '$elderId@example.com',
    adherence: AdherenceSummary(
      from: '2026-01-01',
      to: '2026-01-30',
      scheduled: 0,
      reminded: 0,
      taken: takenRate == null ? 0 : 1,
      skipped: 0,
      missed: 0,
      totalDue: takenRate == null ? 0 : 1,
      takenRate: takenRate,
    ),
    activity: const ElderActivitySummary(daysInRange: 7, activeDays: 3, medicineInteractionDays: 3, gameSessionDays: 1),
    activeEmergency: activeEmergency,
  );
}

Future<void> _loginAsCaregiver(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'caregiver@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'correct-horse-1');
  await tester.tap(find.text('Log In'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with no linked elders, home offers to connect someone and leads to the Elders tab', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.userToReturn = _caregiver;
    harness.dashboard.dashboardToReturn = const [];
    await _loginAsCaregiver(tester);

    await tester.scrollUntilVisible(find.text('Connect Someone'), 250, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('No loved one connected yet.'), findsOneWidget);
    await tester.tap(find.text('Connect Someone'));
    await tester.pumpAndSettle();
    expect(find.text('Your Elders'), findsOneWidget);
  });

  testWidgets('shows each linked elder (switchable), 30-day adherence, active days and an emergency banner', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.userToReturn = _caregiver;
    harness.dashboard.dashboardToReturn = [
      _row(elderId: 'e1', name: 'Grandma Rose', takenRate: 90),
      _row(elderId: 'e2', name: 'Grandpa Joe', activeEmergency: true),
    ];
    await _loginAsCaregiver(tester);
    final page = find.byType(Scrollable).first;

    // Emergency surfaces for any linked elder, even one not currently selected.
    expect(find.bySemanticsLabel('Emergency alert. Please check on Grandpa Joe.'), findsOneWidget);

    // First elder is selected by default.
    await tester.scrollUntilVisible(find.bySemanticsLabel('Activity: Active 3 of last 7 days'), 300, scrollable: page);
    expect(find.bySemanticsLabel('Viewing Grandma Rose. Change loved one.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('90%'), 300, scrollable: page);
    expect(find.text('90%'), findsOneWidget);

    // Switch to the second elder through the loved-one picker.
    await tester.scrollUntilVisible(find.bySemanticsLabel('Viewing Grandma Rose. Change loved one.'), -300, scrollable: page);
    await tester.tap(find.bySemanticsLabel('Viewing Grandma Rose. Change loved one.'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Grandpa Joe'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Viewing Grandpa Joe. Change loved one.'), findsOneWidget);
    expect(find.bySemanticsLabel('Safety: Active emergency'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No doses due yet'), 300, scrollable: page);
    expect(find.text('No doses due yet'), findsOneWidget);
  });

  testWidgets('View Alert on the emergency banner opens the Alerts tab', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.userToReturn = _caregiver;
    harness.dashboard.dashboardToReturn = [_row(elderId: 'e2', name: 'Grandpa Joe', activeEmergency: true)];
    await _loginAsCaregiver(tester);

    await tester.tap(find.text('View Alert'));
    await tester.pumpAndSettle();
    expect(find.text('View Alert'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Alerts'), findsOneWidget);
  });

  testWidgets('the Notices tab lists notifications and marking one read updates it', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.userToReturn = _caregiver;
    harness.notifications.notificationsToReturn = [
      AppNotification(id: 'n1', type: AppNotificationType.missedDose, title: 'A medicine dose was missed', body: 'Body text', createdAt: DateTime(2026, 1, 1)),
    ];
    await _loginAsCaregiver(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Notices'));
    await tester.pumpAndSettle();

    expect(find.text('A medicine dose was missed'), findsOneWidget);
    expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mark_email_read_outlined));
    await tester.pumpAndSettle();

    expect(harness.notifications.lastMarkedReadId, 'n1');
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('a caregiver can mute missed-dose alerts from Settings', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.userToReturn = _caregiver;
    await _loginAsCaregiver(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(SwitchListTile);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(harness.auth.userToReturn.notifyOnMissedDose, false);
  });
}
