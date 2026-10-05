import 'package:elderly_care_app/core/theme/care_theme.dart';
import 'package:elderly_care_app/features/caregiver_onboarding/presentation/caregiver_intro_screen.dart';
import 'package:elderly_care_app/shared/widgets/care/care_buttons.dart';
import 'package:elderly_care_app/shared/widgets/care/care_feature_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _pump(WidgetTester tester, {Size size = const Size(390, 844), double textScale = 1.0, bool reduceMotion = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const CaregiverIntroScreen()),
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
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows headline, subtitle, four benefits, step 2 of 2 and Next', (tester) async {
    await _pump(tester);
    expect(find.bySemanticsLabel('Care Today for a Brighter Tomorrow'), findsOneWidget);
    expect(find.text('Trusted caregiving support\nfor your loved ones.'), findsOneWidget);
    expect(find.byType(CareFeatureTile), findsNWidgets(4));
    for (final label in ['Professional\nCaregivers', 'Verified\n& Safe', 'In-Home\nCare', 'Personalized\nCare Plans']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Step 2 of 2'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.textContaining('CareConnect'), findsNothing);
  });

  testWidgets('benefit tiles are announced as single readable labels', (tester) async {
    await _pump(tester);
    for (final label in ['Professional Caregivers', 'Verified & Safe', 'In-Home Care', 'Personalized Care Plans']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
  });

  testWidgets('tiles form an aligned 2x2 grid', (tester) async {
    await _pump(tester);
    final rects = [for (final e in find.byType(CareFeatureTile).evaluate()) tester.getRect(find.byWidget(e.widget))];
    expect(rects[0].top, rects[1].top);
    expect(rects[2].top, rects[3].top);
    expect(rects[0].left, rects[2].left);
    expect(rects[1].left, rects[3].left);
    expect(rects[0].width, closeTo(rects[1].width, 0.5));
    expect(rects[0].height, rects[1].height);
  });

  testWidgets('Next goes to the existing login screen (page 2 is the last step)', (tester) async {
    await _pump(tester);
    await _tapVisible(tester, 'Next');
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('Skip goes to the existing login screen', (tester) async {
    await _pump(tester);
    await _tapVisible(tester, 'Skip');
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('Next uses the shared filled CTA and both actions meet 48dp', (tester) async {
    await _pump(tester);
    expect(find.byType(CarePrimaryCta), findsOneWidget);
    expect(tester.getSize(find.byType(CarePrimaryCta)).height, greaterThanOrEqualTo(68));
    final skip = tester.getSize(find.byType(CareSoftPillButton));
    expect(skip.height, greaterThanOrEqualTo(48));
    expect(skip.width, greaterThanOrEqualTo(48));
  });

  testWidgets('renders fully with reduced motion (no entrance animation)', (tester) async {
    await _pump(tester, reduceMotion: true);
    expect(tester.takeException(), isNull);
    expect(find.text('Next'), findsOneWidget);
  });

  group('lays out without overflow or clipped actions', () {
    const sizes = {
      'small 320x568': Size(320, 568),
      'compact 360x640': Size(360, 640),
      'standard 390x844': Size(390, 844),
      'large 430x932': Size(430, 932),
      'desktop browser window 1280x720': Size(1280, 720),
    };
    for (final entry in sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pump(tester, size: entry.value);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Next'));
        await tester.pumpAndSettle();
        final cta = tester.getRect(find.byType(CarePrimaryCta));
        expect(cta.bottom, lessThanOrEqualTo(entry.value.height));
        expect(cta.top, greaterThanOrEqualTo(0));
      });
    }

    testWidgets('large system font on a small phone', (tester) async {
      await _pump(tester, size: const Size(360, 640), textScale: 2.0);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Next'));
      expect(tester.takeException(), isNull);
    });
  });
}
