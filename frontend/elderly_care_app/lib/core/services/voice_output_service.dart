import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks the voice assistant's response aloud, on-device. Failing to speak must never
/// block the response text from showing on screen — see docs/architecture.md: touch
/// fallback is always available for every voice feature.
class VoiceOutputService {
  VoiceOutputService() : _tts = FlutterTts();
  final FlutterTts _tts;

  Future<void> speak(String text, {required String languageCode}) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(languageCode);
      // A slower rate than the plugin default is easier for an elderly user to follow.
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (_) {
      // Ignored: the response is already shown as text regardless of whether TTS works.
    }
  }

  Future<void> stop() => _tts.stop();
}

final voiceOutputServiceProvider = Provider<VoiceOutputService>((ref) => VoiceOutputService());
