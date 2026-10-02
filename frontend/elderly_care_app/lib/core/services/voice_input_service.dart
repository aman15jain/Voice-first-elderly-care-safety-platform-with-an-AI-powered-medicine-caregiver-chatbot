import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// On-device speech-to-text for the voice assistant screen. Only the resulting transcript
/// ever leaves the device (sent to the backend to be matched deterministically) — audio
/// itself is never recorded or uploaded, see docs/architecture.md.
class VoiceInputService {
  VoiceInputService() : _speech = SpeechToText();
  final SpeechToText _speech;

  /// Listens for a single utterance and returns its final transcript, or null if speech
  /// recognition is unavailable, times out, or nothing was understood — callers must treat
  /// null as "please try again", never as an error to surface raw.
  Future<String?> listenOnce({required String localeId, Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final available = await _speech.initialize();
      if (!available) return null;

      final completer = Completer<String?>();
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult && !completer.isCompleted) {
            completer.complete(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.confirmation,
          listenFor: timeout,
          pauseFor: const Duration(seconds: 3),
        ),
      );

      final words = await completer.future.timeout(timeout + const Duration(seconds: 2), onTimeout: () => null);
      await _speech.stop();
      return (words == null || words.trim().isEmpty) ? null : words.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> cancel() => _speech.cancel();
}

final voiceInputServiceProvider = Provider<VoiceInputService>((ref) => VoiceInputService());
