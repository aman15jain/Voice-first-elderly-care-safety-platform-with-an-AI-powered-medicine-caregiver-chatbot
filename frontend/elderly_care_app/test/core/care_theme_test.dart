import 'package:elderly_care_app/core/theme/care_theme.dart';
import 'package:elderly_care_app/core/theme/care_tokens.dart';
import 'package:elderly_care_app/features/auth/domain/app_user.dart';
import 'package:elderly_care_app/features/family/presentation/family_screen.dart';
import 'package:elderly_care_app/features/profile/presentation/profile_screen.dart';
import 'package:elderly_care_app/features/profile/presentation/settings_screen.dart';
import 'package:elderly_care_app/shared/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

EditableText _editable(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText));

ThemeData _themeAt(WidgetTester tester, Finder finder) => Theme.of(tester.element(finder));

bool _isSathi(ThemeData theme) => theme.scaffoldBackgroundColor == CareColors.background && theme.colorScheme.primary == CareColors.primaryDark;

Future<void> _login(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, 'correct-horse-1');
  await tester.tap(find.text('Log In'));
  await tester.pumpAndSettle();
}

void main() {
  for (final comfort in [false, true]) {
    group('Sathi theme (${comfort ? 'elder comfort' : 'standard'}) keeps entered text black and visible', () {
      Future<void> pumpField(WidgetTester tester, Widget field) => tester.pumpWidget(
        MaterialApp(
          theme: CareTheme.data(comfort: comfort),
          home: Scaffold(body: Form(child: field)),
        ),
      );

      testWidgets('TextField, focused and typed', (tester) async {
        await pumpField(tester, const TextField(decoration: InputDecoration(labelText: 'Name')));
        expect(_editable(tester).style.color, CareColors.inputText);
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'Rose');
        await tester.pump();
        expect(_editable(tester).style.color, CareColors.inputText);
        expect(find.text('Rose'), findsOneWidget);
      });

      testWidgets('TextFormField, obscured password and multiline', (tester) async {
        await pumpField(tester, TextFormField(obscureText: true));
        expect(_editable(tester).style.color, CareColors.inputText);
        expect(_editable(tester).obscureText, isTrue);

        await pumpField(tester, const TextField(maxLines: 4));
        expect(_editable(tester).style.color, CareColors.inputText);
      });

      testWidgets('hint stays distinct from typed text; cursor visible', (tester) async {
        await pumpField(tester, const TextField(decoration: InputDecoration(hintText: 'Search')));
        expect(tester.widget<Text>(find.text('Search')).style?.color, isNot(CareColors.inputText));
        expect(_editable(tester).cursorColor, isNot(Colors.transparent));
      });
    });
  }

  test('the elder comfort theme is the same design at larger sizes', () {
    final standard = CareTheme.data();
    final comfort = CareTheme.data(comfort: true);
    expect(comfort.colorScheme.primary, standard.colorScheme.primary);
    expect(comfort.scaffoldBackgroundColor, standard.scaffoldBackgroundColor);
    expect(comfort.textTheme.bodyLarge!.fontSize, greaterThan(standard.textTheme.bodyLarge!.fontSize!));
    expect(comfort.filledButtonTheme.style!.minimumSize!.resolve({})!.height, 64);
  });

  testWidgets('shared ErrorView renders the Sathi error state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CareTheme.data(),
        home: const Scaffold(body: ErrorView(message: 'Network is down')),
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Network is down'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing); // no retry callback given
  });

  group('one Sathi design system for every role', () {
    testWidgets('signed out: the entry flow uses the Sathi theme', (tester) async {
      await pumpApp(tester);
      expect(_isSathi(_themeAt(tester, find.text('Welcome Back'))), isTrue);
    });

    testWidgets('caregiver: Elders, Profile and Settings use the standard Sathi theme', (tester) async {
      final harness = await pumpApp(tester);
      harness.auth.userToReturn = const AppUser(id: 'cg1', email: 'caregiver@example.com', role: AppRole.caregiver, preferredLanguage: 'en', fullName: 'Alex');
      await _login(tester, 'caregiver@example.com');

      await tester.tap(find.widgetWithText(NavigationDestination, 'Elders'));
      await tester.pumpAndSettle();
      final theme = _themeAt(tester, find.byType(FamilyScreen));
      expect(_isSathi(theme), isTrue);
      expect(theme.textTheme.bodyLarge!.fontSize, CareTheme.data().textTheme.bodyLarge!.fontSize);
      expect(find.text('No loved one connected yet.'), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pumpAndSettle();
      expect(_isSathi(_themeAt(tester, find.byType(ProfileScreen))), isTrue);
      expect(find.text('Caregiver'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(_isSathi(_themeAt(tester, find.byType(SettingsScreen))), isTrue);
    });

    testWidgets('elder: the same screens use the Sathi theme at comfort sizes', (tester) async {
      await pumpApp(tester);
      await _login(tester, 'elder@example.com');

      await tester.tap(find.widgetWithText(NavigationDestination, 'Family'));
      await tester.pumpAndSettle();
      final theme = _themeAt(tester, find.byType(FamilyScreen));
      expect(_isSathi(theme), isTrue);
      expect(theme.textTheme.bodyLarge!.fontSize, CareTheme.data(comfort: true).textTheme.bodyLarge!.fontSize);
      expect(find.text('No caregivers linked yet.'), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pumpAndSettle();
      expect(_isSathi(_themeAt(tester, find.byType(ProfileScreen))), isTrue);
      expect(find.text('Elder'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(_isSathi(_themeAt(tester, find.byType(SettingsScreen))), isTrue);
    });
  });
}
