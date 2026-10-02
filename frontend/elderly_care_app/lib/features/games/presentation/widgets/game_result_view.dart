import 'package:flutter/material.dart';

import '../../../../shared/widgets/big_button.dart';
import '../../domain/game_models.dart';

/// Shown after a round ends. Posting the session and any error handling is the caller's
/// job (each game screen already holds the repository call) — this is display only.
class GameResultView extends StatelessWidget {
  const GameResultView({required this.result, required this.onDone, super.key, this.isSaving = false});

  final GameSessionResult result;
  final VoidCallback onDone;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              result.completed ? Icons.emoji_events : Icons.flag,
              size: 64,
              color: result.completed ? Colors.amber.shade700 : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(result.completed ? 'Well done!' : 'Good try!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            _StatRow(label: 'Score', value: '${result.score}'),
            _StatRow(label: 'Mistakes', value: '${result.mistakes}'),
            _StatRow(label: 'Time', value: '${result.durationSeconds}s'),
            const SizedBox(height: 28),
            SizedBox(width: 220, child: BigButton(label: 'Done', icon: Icons.check, isLoading: isSaving, onPressed: onDone)),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 18))),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
