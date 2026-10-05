import 'package:elderly_care_app/core/theme/care_theme.dart';
import 'package:elderly_care_app/features/caregiver_onboarding/presentation/caregiver_welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _pump(WidgetTester tester, {Size size = const Size(390, 844), double textScale = 1.0, CaregiverWelcomeContent? content}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => CaregiverWelcomeScreen(content: content ?? const CaregiverWelcomeContent()),
      ),
      GoRoute(
        path: '/welcome/intro',
        builder: (_, _) => const Scaffold(body: Text('PAGE 2')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: CareTheme.data(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows brand, headline, description, benefits, stat card and CTAs', (tester) async {
    await _pump(tester);
    expect(find.text('Sathi'), findsOneWidget);
    expect(find.textContaining('CareConnect'), findsNothing);
    expect(find.bySemanticsLabel('Sathi. Care Today for a Brighter Tomorrow'), findsOneWidget);
    expect(find.textContaining('Compassionate'), findsOneWidget);
    expect(find.textContaining('Find verified caregivers'), findsOneWidget);
    expect(find.text('Verified\nCaregivers'), findsOneWidget);
    expect(find.text('Safe &\nReliable'), findsOneWidget);
    expect(find.text('Personalized\nCare Plans'), findsOneWidget);
    expect(find.text('10,000+'), findsOneWidget);
    expect(find.text('Families Trust Us'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('stat card content is configurable', (tester) async {
    await _pump(
      tester,
      content: const CaregiverWelcomeContent(statValue: '42', statLabel: 'Pilot Families'),
    );
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Pilot Families'), findsOneWidget);
    expect(find.text('10,000+'), findsNothing);
  });

  testWidgets('Get Started goes to page 2', (tester) async {
    await _pump(tester);
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE 2'), findsOneWidget);
  });

  testWidgets('Skip goes to the existing login screen', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('Sign In goes to the existing login screen', (tester) async {
    await _pump(tester);
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('interactive controls meet a 48dp minimum touch target', (tester) async {
    await _pump(tester);
    for (final label in ['Skip', 'Get Started', 'Sign In']) {
      await tester.ensureVisible(find.text(label));
      final target = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).evaluate().isNotEmpty
          ? find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first
          : find.ancestor(of: find.text(label), matching: find.byType(TextButton)).first;
      final size = tester.getSize(target);
      expect(size.height, greaterThanOrEqualTo(48), reason: '$label height');
      expect(size.width, greaterThanOrEqualTo(48), reason: '$label width');
    }
  });

  group('lays out without overflow or clipped actions', () {
    const sizes = {
      'small 320x568': Size(320, 568),
      'compact 360x640': Size(360, 640),
      'standard 390x844': Size(390, 844),
      'large 430x932': Size(430, 932),
      'tablet-ish 600x960': Size(600, 960),
      'desktop browser window 1280x720': Size(1280, 720),
    };
    for (final entry in sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pump(tester, size: entry.value);
        expect(tester.takeException(), isNull);
        // The CTA is reachable (scrolls into view on short screens).
        await tester.ensureVisible(find.text('Get Started'));
        await tester.pumpAndSettle();
        final cta = tester.getRect(find.text('Get Started'));
        expect(cta.bottom, lessThanOrEqualTo(entry.value.height));
        expect(cta.top, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('large system font on a small phone', (tester) async {
      await _pump(tester, size: const Size(360, 640), textScale: 2.0);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sign In'));
      expect(tester.takeException(), isNull);
    });
  });
}
