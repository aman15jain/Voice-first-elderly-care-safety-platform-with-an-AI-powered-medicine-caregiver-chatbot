import 'package:elderly_care_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget field) => tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Form(child: field))),
    );

EditableText _editable(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText));

void main() {
  group('global theme gives every text input black entered text', () {
    testWidgets('plain TextField, unfocused and focused', (tester) async {
      await _pump(tester, const TextField(decoration: InputDecoration(labelText: 'Name', hintText: 'Your name')));
      expect(_editable(tester).style.color, Colors.black);

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'John');
      await tester.pump();
      expect(_editable(tester).style.color, Colors.black);
      expect(find.text('John'), findsOneWidget);
    });

    testWidgets('TextFormField', (tester) async {
      await _pump(tester, TextFormField(decoration: const InputDecoration(labelText: 'Email')));
      expect(_editable(tester).style.color, Colors.black);
    });

    testWidgets('password field is black and still obscured', (tester) async {
      await _pump(tester, TextFormField(obscureText: true));
      expect(_editable(tester).style.color, Colors.black);
      expect(_editable(tester).obscureText, isTrue);
    });

    testWidgets('multiline field', (tester) async {
      await _pump(tester, const TextField(maxLines: 4));
      expect(_editable(tester).style.color, Colors.black);
    });

    testWidgets('hint text keeps its own (non-black) color and the cursor stays visible', (tester) async {
      await _pump(tester, const TextField(decoration: InputDecoration(hintText: 'Search')));
      final hint = tester.widget<Text>(find.text('Search'));
      expect(hint.style?.color, isNot(Colors.black));
      expect(_editable(tester).cursorColor, isNot(Colors.transparent));
    });
  });
}
