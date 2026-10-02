import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/game_models.dart';
import 'widgets/difficulty_picker.dart';
import 'widgets/game_result_view.dart';
import 'widgets/game_session_recorder.dart';

const _symbols = ['🍎', '🍌', '🍇', '🍊', '🍓', '🍒'];

int _pairsForDifficulty(int difficulty) => switch (difficulty) { 1 => 3, 2 => 4, _ => 6 };

class _Card {
  _Card(this.symbol);
  final String symbol;
  bool isFlipped = false;
  bool isMatched = false;
}

/// Classic pairs-matching memory game. Entirely on-device — the backend only records
/// the finished score (spec section 17).
class MemoryMatchScreen extends ConsumerStatefulWidget {
  const MemoryMatchScreen({required this.game, super.key});
  final CognitiveGame game;

  @override
  ConsumerState<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen> {
  List<_Card>? _cards;
  int? _firstFlippedIndex;
  bool _locked = false;
  int _mistakes = 0;
  DateTime? _startedAt;
  GameSessionResult? _result;
  bool _isSaving = false;

  void _start(int difficulty) {
    final pairs = _pairsForDifficulty(difficulty);
    final deck = [for (final s in _symbols.take(pairs)) ...[_Card(s), _Card(s)]]..shuffle(Random());
    setState(() {
      _cards = deck;
      _mistakes = 0;
      _firstFlippedIndex = null;
      _locked = false;
      _startedAt = DateTime.now();
      _result = null;
    });
    _pendingDifficulty = difficulty;
  }

  int _pendingDifficulty = 1;

  Future<void> _onTapCard(int index) async {
    final cards = _cards!;
    if (_locked || cards[index].isFlipped || cards[index].isMatched) return;

    setState(() => cards[index].isFlipped = true);

    if (_firstFlippedIndex == null) {
      _firstFlippedIndex = index;
      return;
    }

    final firstIndex = _firstFlippedIndex!;
    _firstFlippedIndex = null;
    _locked = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (cards[firstIndex].symbol == cards[index].symbol) {
      setState(() {
        cards[firstIndex].isMatched = true;
        cards[index].isMatched = true;
        _locked = false;
      });
    } else {
      setState(() {
        cards[firstIndex].isFlipped = false;
        cards[index].isFlipped = false;
        _mistakes++;
        _locked = false;
      });
    }

    if (cards.every((c) => c.isMatched)) {
      final duration = DateTime.now().difference(_startedAt!).inSeconds.clamp(1, 3600);
      final pairs = cards.length ~/ 2;
      final score = (pairs * 100 - _mistakes * 10).clamp(0, 10000);
      setState(() => _result = GameSessionResult(difficulty: _pendingDifficulty, score: score, mistakes: _mistakes, durationSeconds: duration, completed: true));
    }
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
        child: _cards == null
            ? DifficultyPicker(gameName: widget.game.name, description: widget.game.description, suggested: widget.game.suggestedDifficulty, onStart: _start)
            : _result != null
            ? GameResultView(result: _result!, isSaving: _isSaving, onDone: () => _finish(context))
            : _buildBoard(),
      ),
    );
  }

  Widget _buildBoard() {
    final cards = _cards!;
    final columns = cards.length <= 6 ? 3 : 4;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Mistakes: $_mistakes', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemCount: cards.length,
              itemBuilder: (context, i) {
                final card = cards[i];
                final shown = card.isFlipped || card.isMatched;
                return GestureDetector(
                  onTap: () => _onTapCard(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: card.isMatched ? Colors.green.shade100 : (shown ? Colors.white : Theme.of(context).colorScheme.primaryContainer),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    alignment: Alignment.center,
                    child: Text(shown ? card.symbol : '?', style: const TextStyle(fontSize: 32)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
