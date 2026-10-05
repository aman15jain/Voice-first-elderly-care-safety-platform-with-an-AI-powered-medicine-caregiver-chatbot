import 'package:dio/dio.dart';
import 'package:elderly_care_app/features/ai/data/ai_repository.dart';
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

const _assistant = 'Sathi AI. How can I help with care today? Get a care summary for Grandma Rose.';

ElderDashboardRow _row({String elderId = 'e1', String name = 'Grandma Rose', int? takenRate = 90}) => ElderDashboardRow(
  elderId: elderId,
  elderName: name,
  elderEmail: '$elderId@example.com',
  adherence: AdherenceSummary(
    from: '2026-01-01',
    to: '2026-01-30',
    scheduled: 0,
    reminded: 0,
    taken: 9,
    skipped: 0,
    missed: 1,
    totalDue: 10,
    takenRate: takenRate,
  ),
  activity: const ElderActivitySummary(daysInRange: 7, activeDays: 5, medicineInteractionDays: 4, gameSessionDays: 2),
  activeEmergency: false,
);

DateTime _today(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour);
}

Future<TestHarness> _pumpCaregiverHome(WidgetTester tester, {void Function(TestHarness h)? arrange}) async {
  final harness = await pumpApp(tester);
  harness.auth.userToReturn = _caregiver;
  harness.dashboard.dashboardToReturn = [_row()];
  arrange?.call(harness);
  await tester.enterText(find.byType(TextFormField).first, 'caregiver@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'correct-horse-1');
  await tester.tap(find.text('Log In'));
  await tester.pumpAndSettle();
  return harness;
}

Finder get _page => find.byType(Scrollable).first;

Future<void> _scrollTo(WidgetTester tester, Finder finder, {double delta = 250}) async {
  await tester.scrollUntilVisible(finder, delta, scrollable: _page);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('greets the signed-in caregiver by name with the Sathi brand, bell and profile', (tester) async {
    await _pumpCaregiverHome(tester);
    expect(find.text('Alex 👋'), findsOneWidget);
    expect(find.text('Sathi'), findsOneWidget);
    expect(find.textContaining(RegExp('Good (Morning|Afternoon|Evening),')), findsOneWidget);
    expect(find.bySemanticsLabel('Your profile'), findsOneWidget);
    expect(find.textContaining('CareConnect'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Your profile'));
    await tester.pumpAndSettle();
    expect(find.text('Alex 👋'), findsNothing);
  });

  testWidgets("today's snapshot and care plan come from the selected elder's real doses", (tester) async {
    final harness = await _pumpCaregiverHome(
      tester,
      arrange: (h) {
        h.medicines.medicinesToReturn = const [
          Medicine(id: 'm1', name: 'Metformin', dosage: '500 mg', isActive: true),
          Medicine(id: 'm2', name: 'Amlodipine', dosage: '5 mg', isActive: true),
        ];
        h.medicines.dosesToReturn = [
          MedicineDose(id: 'd1', medicineId: 'm1', scheduledFor: _today(8), status: DoseStatus.taken),
          MedicineDose(id: 'd2', medicineId: 'm2', scheduledFor: _today(20), status: DoseStatus.scheduled),
          MedicineDose(id: 'd3', medicineId: 'm1', scheduledFor: _today(13), status: DoseStatus.missed),
        ];
      },
    );

    // Scoped to the linked elder (the backend enforces the family link).
    expect(harness.medicines.lastDosesElderId, 'e1');
    await _scrollTo(tester, find.bySemanticsLabel('Safety: No active alerts'));
    expect(find.bySemanticsLabel('Medicines: 1 of 3 taken'), findsOneWidget);
    expect(find.text('1 missed'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Next dose: 8:00\sPM · Amlodipine$')), findsOneWidget);
    expect(find.bySemanticsLabel('Activity: Active 5 of last 7 days'), findsOneWidget);

    await _scrollTo(tester, find.bySemanticsLabel(RegExp(r'^8:00\sPM, Amlodipine 5 mg, Upcoming$')));
    expect(find.bySemanticsLabel(RegExp(r'^8:00\sAM, Metformin 500 mg, Taken$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^1:00\sPM, Metformin 500 mg, Missed$')), findsOneWidget);
  });

  testWidgets('no medicines today shows honest empty states', (tester) async {
    await _pumpCaregiverHome(tester);
    await _scrollTo(tester, find.bySemanticsLabel('Medicines: None scheduled today'));
    await _scrollTo(tester, find.text('No medicines scheduled for today.'));
    expect(find.text("Medicines and their times are set up in Grandma Rose's Sathi app."), findsOneWidget);
  });

  testWidgets('Sathi AI is fetched only on request, opens in a sheet, and is shared with the insight card', (tester) async {
    final harness = await _pumpCaregiverHome(tester);
    expect(harness.ai.requestedElderIds, isEmpty, reason: 'opening home must not trigger an LLM call');

    await tester.tap(find.bySemanticsLabel(_assistant));
    await tester.pumpAndSettle();
    expect(harness.ai.requestedElderIds, ['e1']);
    expect(find.text('Medicines were taken on time this week.'), findsOneWidget);
    expect(find.text("AI-generated from Grandma Rose's care records."), findsOneWidget);

    // Close the sheet; the insight card further down shows the same result — no second call.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('View Insight'));
    expect(find.text('“Medicines were taken on time this week.”'), findsOneWidget);
    expect(harness.ai.requestedElderIds, ['e1']);
  });

  testWidgets('the insight card can start the insight too', (tester) async {
    final harness = await _pumpCaregiverHome(tester);
    await _scrollTo(tester, find.text('Get Care Insight'));
    await tester.tap(find.text('Get Care Insight'));
    await tester.pumpAndSettle();
    expect(harness.ai.requestedElderIds, ['e1']);
    expect(find.text('Medicines were taken on time this week.'), findsOneWidget);
  });

  testWidgets('an AI failure shows a friendly message, never the raw error, and can retry', (tester) async {
    final harness = await _pumpCaregiverHome(
      tester,
      arrange: (h) => h.ai.errorToThrow = DioException(
        requestOptions: RequestOptions(path: '/api/ai/caregiver-insight'),
        message: 'Gemini quota exceeded at http://internal',
      ),
    );

    await tester.tap(find.bySemanticsLabel(_assistant));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text("Sathi AI couldn't prepare an insight right now.")), findsOneWidget);
    expect(find.textContaining('Gemini'), findsNothing);
    expect(find.textContaining('http'), findsNothing);

    harness.ai.errorToThrow = null;
    harness.ai.insightToReturn = const CaregiverInsight(response: 'All good today.', sources: []);
    await tester.tap(find.descendant(of: sheet, matching: find.text('Try again')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: sheet, matching: find.text('All good today.')), findsOneWidget);
  });

  testWidgets("a failing medicines request doesn't break the rest of the dashboard", (tester) async {
    await _pumpCaregiverHome(tester, arrange: (h) => h.medicines.throwNetworkErrorOnFetch = true);

    await _scrollTo(tester, find.textContaining("Today's medicines couldn't load."));
    expect(find.bySemanticsLabel('Activity: Active 5 of last 7 days'), findsOneWidget);
    await _scrollTo(tester, find.text("Today's plan couldn't load."));
    await _scrollTo(tester, find.text('90%'));
    expect(find.bySemanticsLabel('Brain games on 2 of the last 7 days'), findsOneWidget);
  });

  testWidgets('a failing dashboard request keeps Sathi AI, shortcuts and notices usable', (tester) async {
    await _pumpCaregiverHome(
      tester,
      arrange: (h) => h.dashboard.errorToThrow = DioException(
        requestOptions: RequestOptions(path: '/api/family/dashboard'),
        type: DioExceptionType.connectionError,
      ),
    );

    await _scrollTo(tester, find.textContaining("Your loved ones' overview couldn't load."));
    expect(find.text('Retry'), findsOneWidget);
    await _scrollTo(tester, find.bySemanticsLabel('Safety'));
    await _scrollTo(tester, find.text("You're all caught up."));
  });

  testWidgets('unread notices show on the bell, the snapshot, the shortcut and the Notices card', (tester) async {
    await _pumpCaregiverHome(
      tester,
      arrange: (h) => h.notifications.notificationsToReturn = [
        AppNotification(
          id: 'n1',
          type: AppNotificationType.missedDose,
          title: 'A medicine dose was missed',
          body: 'Rose missed her 1 PM dose',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(find.bySemanticsLabel('Notifications, 1 unread'), findsOneWidget);
    await _scrollTo(tester, find.bySemanticsLabel('Notices: 1 unread notice'));
    await _scrollTo(tester, find.bySemanticsLabel('Notices, 1 unread'));
    await _scrollTo(tester, find.text('Rose missed her 1 PM dose'));
    expect(find.text('A medicine dose was missed'), findsOneWidget);

    await _scrollTo(tester, find.bySemanticsLabel('Notifications, 1 unread'), delta: -400);
    await tester.tap(find.bySemanticsLabel('Notifications, 1 unread'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Notifications'), findsOneWidget);
  });

  testWidgets('shortcuts open real screens or jump to sections on the page', (tester) async {
    await _pumpCaregiverHome(tester);

    await _scrollTo(tester, find.bySemanticsLabel('Medicines'));
    await tester.tap(find.bySemanticsLabel('Medicines'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text("Today's Care Plan")).top, lessThan(200), reason: 'jumped to the care plan');

    await _scrollTo(tester, find.bySemanticsLabel('Safety'), delta: -250);
    await tester.tap(find.bySemanticsLabel('Safety'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Alerts'), findsOneWidget);
  });

  testWidgets('Find Care is a secondary coming-soon section with no fake caregivers', (tester) async {
    await _pumpCaregiverHome(tester);
    await _scrollTo(tester, find.text('Coming soon'));
    expect(find.text('Find Care'), findsOneWidget);
    expect(find.text('Need additional professional support?'), findsOneWidget);
    expect(find.text('Nursing\nCare'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining('reviews'), findsNothing);
  });

  testWidgets('lays out without overflow on a small phone, and scrolls to the end', (tester) async {
    await _pumpCaregiverHome(tester);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _scrollTo(tester, find.text('Get Care Insight'), delta: 300);
    expect(tester.takeException(), isNull);
  });
}
