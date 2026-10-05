import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/care/care_states.dart';
import '../../../shared/widgets/care/care_pill.dart';
import '../../../shared/widgets/care/care_connect_logo.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/phone_service.dart';
import '../../../core/services/voice_input_service.dart';
import '../../../core/services/voice_output_service.dart';
import '../../../core/utils/locale_mapping.dart';
import '../../auth/application/auth_controller.dart';
import '../data/voice_repository.dart';
import '../domain/voice_models.dart';

enum VoiceUiState { idle, listening, processing, speaking, error }

const _examplePhrases = [
  "Try saying: 'Did I take my medicine?'",
  "Try saying: 'What medicine do I take?'",
  "Try saying: 'How am I doing this week?'",
  "Try saying: 'Call my daughter'",
];

/// The Voice Assistant screen (spec sections 7/26/35). The mic/STT/backend/TTS pipeline is
/// entirely on-device-plus-deterministic-backend; the only actions it may ever execute are
/// the explicit, allow-listed ones in [_executeAction] — never anything the response text
/// itself implies. Touch fallback (every other screen in the app) is always available.
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  VoiceUiState _state = VoiceUiState.idle;
  String? _transcript;
  String? _responseText;
  String? _errorMessage;

  String get _language => switch (ref.read(authControllerProvider)) {
    AuthAuthenticated(user: final user) => user.preferredLanguage,
    _ => 'en',
  };

  Future<void> _startListening() async {
    setState(() {
      _state = VoiceUiState.listening;
      _transcript = null;
      _responseText = null;
      _errorMessage = null;
    });

    final language = _language;
    final heard = await ref.read(voiceInputServiceProvider).listenOnce(localeId: speechToTextLocale(language));
    if (!mounted) return;

    if (heard == null) {
      setState(() {
        _state = VoiceUiState.error;
        _errorMessage = "I didn't catch that. Please try again, or use the screen instead.";
      });
      return;
    }

    setState(() {
      _transcript = heard;
      _state = VoiceUiState.processing;
    });

    try {
      final result = await ref.read(voiceRepositoryProvider).process(heard, language: language);
      if (!mounted) return;
      setState(() {
        _responseText = result.response;
        _state = VoiceUiState.speaking;
      });
      await ref.read(voiceOutputServiceProvider).speak(result.response, languageCode: ttsLocale(result.language));
      if (!mounted) return;
      setState(() => _state = VoiceUiState.idle);
      await _executeAction(result.action);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = VoiceUiState.error;
        _errorMessage = AppFailure.fromError(e).message;
      });
    }
  }

  /// The only actions this screen will ever execute from a voice response. TRIGGER_SOS
  /// never fires the real emergency itself — it only opens the existing confirmation
  /// screen, so a human always explicitly confirms (spec sections 13/15). Anything else,
  /// including an action type this build doesn't recognize, is silently ignored.
  Future<void> _executeAction(VoiceAction? action) async {
    if (action == null || !mounted) return;
    switch (action.type) {
      case 'CALL_CONTACT':
        if (action.phone != null) await ref.read(phoneServiceProvider).call(action.phone!);
      case 'TRIGGER_SOS':
        if (mounted) context.push('/emergency');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Assistant')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(CareSpacing.screenH - 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_transcript != null) _TranscriptCard(transcript: _transcript!),
                if (_responseText != null) _ResponseCard(response: _responseText!),
                if (_state == VoiceUiState.error && _errorMessage != null) _ErrorCard(message: _errorMessage!),
                if (_state == VoiceUiState.idle && _transcript == null) const _IdleHints(),
                const SizedBox(height: 32),
                _MicButton(state: _state, onPressed: _state == VoiceUiState.idle || _state == VoiceUiState.error ? _startListening : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.state, required this.onPressed});
  final VoiceUiState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isBusy = state == VoiceUiState.listening || state == VoiceUiState.processing || state == VoiceUiState.speaking;
    // Soft halo ring, as on the onboarding pages, around the one big action.
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: state == VoiceUiState.listening ? CareColors.dangerSoft : CareColors.primarySoft, shape: BoxShape.circle),
      child: SizedBox(
        width: 180,
        height: 180,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: state == VoiceUiState.listening ? CareColors.danger : CareColors.primaryDark,
            foregroundColor: Colors.white,
            disabledBackgroundColor: CareColors.primary,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: CareColors.primaryDark,
          ),
          child: isBusy ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.mic, size: 64),
        ),
      ),
    );
  }
}

class _IdleHints extends StatelessWidget {
  const _IdleHints();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Tap the microphone and speak', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: CareSpacing.lg),
        ..._examplePhrases.map(
          (phrase) => Padding(
            padding: const EdgeInsets.symmetric(vertical: CareSpacing.xs),
            child: Text(phrase, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript});
  final String transcript;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CareSpacing.lg + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CareIconTile(icon: Icons.person, size: 40, circle: true),
            const SizedBox(width: CareSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You said', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('"$transcript"', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.response});
  final String response;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: CareSpacing.sm - 2),
      padding: const EdgeInsets.all(CareSpacing.lg + 2),
      decoration: BoxDecoration(color: CareColors.primarySoft, borderRadius: BorderRadius.circular(CareRadius.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CareConnectMark(size: 40),
          const SizedBox(width: CareSpacing.md),
          Expanded(
            child: Text(response, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return CareInlineError(message: message);
  }
}
