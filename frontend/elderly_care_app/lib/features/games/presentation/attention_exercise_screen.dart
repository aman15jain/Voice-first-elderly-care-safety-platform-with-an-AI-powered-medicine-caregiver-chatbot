import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/game_models.dart';
import 'widgets/difficulty_picker.dart';
import 'widgets/game_result_view.dart';
import 'widgets/game_session_recorder.dart';

const _symbolPairs = [('🔵', '🔴'), ('⭐', '🌙'), ('🍀', '🌸'), ('🟦', '🟨'), ('🐱', '🐶')];
const _roundsPerSession = 5;
const _roundSeconds = 6;

int _gridSizeForDifficulty(int difficulty) => switch (difficulty) { 1 => 2, 2 => 3, _ => 4 };

/// Find the one symbol that's different from the rest, before the timer runs out.
class AttentionExerciseScreen extends ConsumerStatefulWidget {
  const AttentionExerciseScreen({required this.game, super.key});
  final CognitiveGame game;

  @override
  ConsumerState<AttentionExerciseScreen> createState() => _AttentionExerciseScreenState();
}

class _AttentionExerciseScreenState extends ConsumerState<AttentionExerciseScreen> {
  int? _difficulty;
  int _round = 0;
  int _correctRounds = 0;
  int _mistakes = 0;
  int _oddIndex = 0;
  late String _common;
  late String _different;
  int _secondsLeft = _roundSeconds;
  Timer? _timer;
  bool _roundActive = false;
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
    });
    _playRound();
  }

  void _playRound() {
    final random = Random();
    final pair = _symbolPairs[random.nextInt(_symbolPairs.length)];
    final gridSize = _gridSizeForDifficulty(_difficulty!);
    setState(() {
      _common = pair.$1;
      _different = pair.$2;
      _oddIndex = random.nextInt(gridSize * gridSize);
      _secondsLeft = _roundSeconds;
      _roundActive = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        _onRoundResolved(correct: false);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onTapCell(int index) {
    if (!_roundActive) return;
    _timer?.cancel();
    _onRoundResolved(correct: index == _oddIndex);
  }

  void _onRoundResolved({required bool correct}) {
    setState(() {
      _roundActive = false;
      if (correct) {
        _correctRounds++;
      } else {
        _mistakes++;
      }
      _round++;
    });
    if (_round >= _roundsPerSession) {
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
      Future<void>.delayed(const Duration(milliseconds: 400), _playRound);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    final gridSize = _gridSizeForDifficulty(_difficulty!);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Round ${_round + 1} of $_roundsPerSession', style: const TextStyle(fontSize: 18)),
              Text('$_secondsLeft s', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridSize, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemCount: gridSize * gridSize,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _onTapCell(i),
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(i == _oddIndex ? _different : _common, style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
