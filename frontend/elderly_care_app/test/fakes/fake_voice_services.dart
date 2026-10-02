import 'package:elderly_care_app/core/services/voice_input_service.dart';
import 'package:elderly_care_app/core/services/voice_output_service.dart';
import 'package:elderly_care_app/features/voice/data/voice_repository.dart';
import 'package:elderly_care_app/features/voice/domain/voice_models.dart';
import 'package:dio/dio.dart';

/// Avoids touching the real speech_to_text platform channel in tests, which has no
/// handler registered — same reasoning as FakeLocationService.
class FakeVoiceInputService extends VoiceInputService {
  String? transcriptToReturn = 'did I take my medicine today';

  @override
  Future<String?> listenOnce({required String localeId, Duration timeout = const Duration(seconds: 8)}) async => transcriptToReturn;
}

/// Records what it was asked to speak instead of touching the real flutter_tts plugin.
class FakeVoiceOutputService extends VoiceOutputService {
  String? lastSpoken;
  String? lastLanguageCode;

  @override
  Future<void> speak(String text, {required String languageCode}) async {
    lastSpoken = text;
    lastLanguageCode = languageCode;
  }
}

class FakeVoiceRepository extends VoiceRepository {
  FakeVoiceRepository() : super(Dio());

  VoiceProcessResult resultToReturn = const VoiceProcessResult(type: 'information', response: 'You have taken 1 of 1 medicines today.', language: 'en');
  String? lastTranscript;

  @override
  Future<VoiceProcessResult> process(String transcript, {String? language}) async {
    lastTranscript = transcript;
    return resultToReturn;
  }
}
