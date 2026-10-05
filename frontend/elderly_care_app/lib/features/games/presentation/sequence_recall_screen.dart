import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/care/care_pill.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/game_models.dart';
import 'widgets/difficulty_picker.dart';
import 'widgets/game_result_view.dart';
import 'widgets/game_session_recorder.dart';

// Four clearly distinct hues from the Sathi palette (the game needs distinct colours).
const _colors = [CareColors.danger, CareColors.accentBlue, CareColors.primary, CareColors.accentAmber];
const _roundsPerSession = 3;

int _baseLengthForDifficulty(int difficulty) => switch (difficulty) {
  1 => 3,
  2 => 4,
  _ => 5,
};

/// "Simon says": watch a sequence of colors light up, then repeat it back in order.
/// Sequence length grows each round; a wrong tap ends the session immediately.
class SequenceRecallScreen extends ConsumerStatefulWidget {
  const SequenceRecallScreen({required this.game, super.key});
  final CognitiveGame game;

  @override
  ConsumerState<SequenceRecallScreen> createState() => _SequenceRecallScreenState();
}

class _SequenceRecallScreenState extends ConsumerState<SequenceRecallScreen> {
  int? _difficulty;
  int _round = 0;
  int _mistakes = 0;
  List<int> _sequence = [];
  int _inputIndex = 0;
  int? _highlighted;
  bool _showingSequence = false;
  DateTime? _startedAt;
  GameSessionResult? _result;
  bool _isSaving = false;

  Future<void> _start(int difficulty) async {
    setState(() {
      _difficulty = difficulty;
      _round = 0;
      _mistakes = 0;
      _startedAt = DateTime.now();
      _result = null;
    });
    await _playRound();
  }

  Future<void> _playRound() async {
    final length = _baseLengthForDifficulty(_difficulty!) + _round;
    final random = Random();
    _sequence = List.generate(length, (_) => random.nextInt(_colors.length));
    _inputIndex = 0;
    setState(() => _showingSequence = true);

    for (final colorIndex in _sequence) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _highlighted = colorIndex);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _highlighted = null);
    }
    if (mounted) setState(() => _showingSequence = false);
  }

  void _onTapColor(int colorIndex) {
    if (_showingSequence || _result != null) return;

    if (colorIndex != _sequence[_inputIndex]) {
      _mistakes++;
      _finishWith(completed: false);
      return;
    }

    _inputIndex++;
    if (_inputIndex == _sequence.length) {
      _round++;
      if (_round >= _roundsPerSession) {
        _finishWith(completed: true);
      } else {
        _playRound();
      }
    }
  }

  void _finishWith({required bool completed}) {
    final duration = DateTime.now().difference(_startedAt!).inSeconds.clamp(1, 3600);
    final score = _round * 100;
    setState(() => _result = GameSessionResult(difficulty: _difficulty!, score: score, mistakes: _mistakes, durationSeconds: duration, completed: completed));
  }

  Future<void> _finish(BuildContext context) async {
    setState(() => _isSaving = true);
    try {
      await submitGameSession(ref, widget.game.id, _result!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.name)),
      body: SafeArea(
        child: _difficulty == null
            ? DifficultyPicker(gameName: widget.game.name, description: widget.game.description, suggested: widget.game.suggestedDifficulty, onStart: _start)
            : _result != null
            ? GameResultView(result: _result!, isSaving: _isSaving, onDone: () => _finish(context))
            : _buildBoard(),
      ),
    );
  }

  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CareStatusPill(label: 'Round ${_round + 1} of $_roundsPerSession'),
          const SizedBox(height: 12),
          Text(_showingSequence ? 'Watch...' : 'Your turn!', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              for (var i = 0; i < _colors.length; i++)
                GestureDetector(
                  onTap: () => _onTapColor(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: _highlighted == i ? _colors[i] : _colors[i].withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(CareRadius.card),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
