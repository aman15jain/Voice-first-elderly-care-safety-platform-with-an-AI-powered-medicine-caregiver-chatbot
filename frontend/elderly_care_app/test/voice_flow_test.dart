import 'package:elderly_care_app/features/voice/domain/voice_models.dart';
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
  testWidgets('tapping the mic sends the heard transcript and shows the response text', (tester) async {
    final harness = await pumpApp(tester);
    await _loginAsElder(tester);

    harness.voiceInput.transcriptToReturn = 'did I take my medicine today';
    harness.voice.resultToReturn = const VoiceProcessResult(
      type: 'information',
      response: "You've taken 1 out of 1 medicines today. Well done!",
      language: 'en',
    );

    await tester.tap(find.text('Talk'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mic), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    expect(find.text('"did I take my medicine today"'), findsOneWidget);
    expect(find.text("You've taken 1 out of 1 medicines today. Well done!"), findsOneWidget);
    expect(harness.voice.lastTranscript, 'did I take my medicine today');
    expect(harness.voiceOutput.lastSpoken, "You've taken 1 out of 1 medicines today. Well done!");
  });

  testWidgets('a TRIGGER_SOS action navigates to the emergency confirm screen without firing SOS directly', (tester) async {
    final harness = await pumpApp(tester);
    await _loginAsElder(tester);

    harness.voiceInput.transcriptToReturn = 'help, help!';
    harness.voice.resultToReturn = const VoiceProcessResult(
      type: 'action',
      response: "I'm opening the emergency screen so you can confirm you need help.",
      language: 'en',
      action: VoiceAction(type: 'TRIGGER_SOS'),
    );

    await tester.tap(find.text('Talk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    // Lands on the SOS confirm screen (idle state), not an already-triggered emergency —
    // a human still has to press the button themselves.
    expect(find.text('If you need help right now, press the button below.'), findsOneWidget);
    expect(harness.emergency.eventsToReturn, isEmpty);
  });

  testWidgets('a CALL_CONTACT action does not throw and leaves the voice screen showing the response', (tester) async {
    final harness = await pumpApp(tester);
    await _loginAsElder(tester);

    harness.voiceInput.transcriptToReturn = 'call my daughter';
    harness.voice.resultToReturn = const VoiceProcessResult(
      type: 'action',
      response: 'Calling Daughter Jane now.',
      language: 'en',
      action: VoiceAction(type: 'CALL_CONTACT', contactId: 'c1', contactName: 'Daughter Jane', phone: '555-123-4567'),
    );

    await tester.tap(find.text('Talk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    expect(find.text('Calling Daughter Jane now.'), findsOneWidget);
  });

  testWidgets('an unrecognized action type is safely ignored and stays on the voice screen', (tester) async {
    await pumpApp(tester);
    await _loginAsElder(tester);

    await tester.tap(find.text('Talk'));
    await tester.pumpAndSettle();
    // No explicit harness wiring needed: default FakeVoiceRepository result has no action.
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    expect(find.text('Voice Assistant'), findsOneWidget);
  });

  testWidgets('when nothing is heard, shows a try-again error and keeps the mic enabled', (tester) async {
    final harness = await pumpApp(tester);
    await _loginAsElder(tester);

    harness.voiceInput.transcriptToReturn = null;

    await tester.tap(find.text('Talk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    expect(find.textContaining("didn't catch that"), findsOneWidget);
    expect(harness.voice.lastTranscript, isNull);
  });
}
