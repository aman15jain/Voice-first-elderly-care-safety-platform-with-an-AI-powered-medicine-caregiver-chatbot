import 'package:elderly_care_app/features/auth/domain/app_user.dart';
import 'package:elderly_care_app/features/dashboard/domain/elder_dashboard_row.dart';
import 'package:elderly_care_app/features/medicines/domain/medicine_models.dart';
import 'package:elderly_care_app/features/notifications/domain/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

const _caregiver = AppUser(id: 'cg1', email: 'caregiver@example.com', role: AppRole.caregiver, preferredLanguage: 'en', fullName: 'Alex', notifyOnMissedDose: true);

ElderDashboardRow _row({required String elderId, required String name, int? takenRate, bool activeEmergency = false}) {
  return ElderDashboardRow(
    elderId: elderId,
    elderName: name,
    elderEmail: '$elderId@example.com',
    adherence: AdherenceSummary(from: '2026-01-01', to: '2026-01-30', scheduled: 0, reminded: 0, taken: takenRate == null ? 0 : 1, skipped: 0, missed: 0, totalDue: takenRate == null ? 0 : 1, takenRate: takenRate),
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
  testWidgets('shows an invite prompt when the caregiver has no linked elders', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.userToReturn = _caregiver;
    harness.dashboard.dashboardToReturn = const [];
    await _loginAsCaregiver(tester);

    expect(find.text('No elders linked yet.'), findsOneWidget);
  });

  testWidgets('shows adherence rate, active days and an emergency banner per linked elder', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.userToReturn = _caregiver;
    harness.dashboard.dashboardToReturn = [
      _row(elderId: 'e1', name: 'Grandma Rose', takenRate: 90),
      _row(elderId: 'e2', name: 'Grandpa Joe', activeEmergency: true),
    ];
    await _loginAsCaregiver(tester);

    expect(find.text('Grandma Rose'), findsOneWidget);
    expect(find.text('90% taken (30d)'), findsOneWidget);
    expect(find.text('Grandpa Joe'), findsOneWidget);
    expect(find.text('No doses due yet'), findsOneWidget);
    expect(find.text('Active emergency — check the Alerts tab'), findsOneWidget);
    expect(find.text('3/7 active days'), findsNWidgets(2));
  });

  testWidgets('the Notices tab lists notifications and marking one read updates it', (tester) async {
    final harness = await pumpApp(tester);
    harness.auth.userToReturn = _caregiver;
    harness.notifications.notificationsToReturn = [
      AppNotification(id: 'n1', type: AppNotificationType.missedDose, title: 'A medicine dose was missed', body: 'Body text', createdAt: DateTime(2026, 1, 1)),
    ];
    await _loginAsCaregiver(tester);

    await tester.tap(find.text('Notices'));
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
