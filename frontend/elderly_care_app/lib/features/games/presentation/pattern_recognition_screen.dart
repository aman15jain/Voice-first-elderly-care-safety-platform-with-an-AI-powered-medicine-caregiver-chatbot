import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/game_models.dart';
import 'widgets/difficulty_picker.dart';
import 'widgets/game_result_view.dart';
import 'widgets/game_session_recorder.dart';

const _palette = ['🔵', '🔴', '🟢', '🟡', '🟣'];
const _roundsPerSession = 5;

int _periodForDifficulty(int difficulty) => switch (difficulty) { 1 => 2, 2 => 2, _ => 3 };

class _Round {
  _Round(int period) {
    final shuffled = [..._palette]..shuffle(Random());
    final symbols = shuffled.take(period).toList();
    final visibleLength = period * 2;
    sequence = List.generate(visibleLength, (i) => symbols[i % period]);
    final correct = symbols[visibleLength % period];
    final distractorPool = _palette.where((s) => s != correct).toList()..shuffle(Random());
    options = [correct, ...distractorPool.take(2)]..shuffle(Random());
    correctAnswer = correct;
  }

  late final List<String> sequence;
  late final List<String> options;
  late final String correctAnswer;
}

/// Spot what comes next in a repeating pattern of symbols.
class PatternRecognitionScreen extends ConsumerStatefulWidget {
  const PatternRecognitionScreen({required this.game, super.key});
  final CognitiveGame game;

  @override
  ConsumerState<PatternRecognitionScreen> createState() => _PatternRecognitionScreenState();
}

class _PatternRecognitionScreenState extends ConsumerState<PatternRecognitionScreen> {
  int? _difficulty;
  int _round = 0;
  int _correctRounds = 0;
  int _mistakes = 0;
  _Round? _current;
  String? _selectedOption;
  DateTime? _startedAt;
  GameSessionResult? _result;
  bool _isSaving = false;

  void _start(int difficulty) {
    setState(() {
      _difficulty = difficulty;
      _round = 0;
      _correctRounds = 0;
      _mistakes = 0;
      _startedAt = DateTime.now();
      _result = null;
      _selectedOption = null;
      _current = _Round(_periodForDifficulty(difficulty));
    });
  }

  void _onSelect(String option) {
    if (_selectedOption != null) return; // one answer per round
    final correct = option == _current!.correctAnswer;
    setState(() {
      _selectedOption = option;
      if (correct) {
        _correctRounds++;
      } else {
        _mistakes++;
      }
    });

    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final nextRound = _round + 1;
      if (nextRound >= _roundsPerSession) {
        final duration = DateTime.now().difference(_startedAt!).inSeconds.clamp(1, 3600);
        setState(
          () => _result = GameSessionResult(
            difficulty: _difficulty!,
            score: _correctRounds * 100,
            mistakes: _mistakes,
            durationSeconds: duration,
            completed: true,
          ),
        );
      } else {
        setState(() {
          _round = nextRound;
          _selectedOption = null;
          _current = _Round(_periodForDifficulty(_difficulty!));
        });
      }
    });
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
            : _buildRound(),
      ),
    );
  }

  Widget _buildRound() {
    final round = _current!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Round ${_round + 1} of $_roundsPerSession', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            children: [
              for (final symbol in round.sequence) Text(symbol, style: const TextStyle(fontSize: 36)),
              const Text('❓', style: TextStyle(fontSize: 36)),
            ],
          ),
          const SizedBox(height: 40),
          const Text('What comes next?', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final option in round.options)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GestureDetector(
                    onTap: () => _onSelect(option),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _selectedOption == null
                            ? Colors.grey.shade100
                            : (option == round.correctAnswer ? Colors.green.shade100 : (option == _selectedOption ? Colors.red.shade100 : Colors.grey.shade100)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      alignment: Alignment.center,
                      child: Text(option, style: const TextStyle(fontSize: 32)),
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
