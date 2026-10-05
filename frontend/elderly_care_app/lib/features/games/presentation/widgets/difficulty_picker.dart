import 'package:flutter/material.dart';

import '../../../../core/theme/care_tokens.dart';
import '../../../../shared/widgets/big_button.dart';

const _labels = {1: 'Easy', 2: 'Medium', 3: 'Hard'};

/// Shown before a game starts. Defaults to the backend's deterministic suggestion, but the
/// elder can always pick a different level themself — this is a suggestion, not a lock.
class DifficultyPicker extends StatefulWidget {
  const DifficultyPicker({required this.gameName, required this.description, required this.suggested, required this.onStart, super.key});

  final String gameName;
  final String description;
  final int suggested;
  final ValueChanged<int> onStart;

  @override
  State<DifficultyPicker> createState() => _DifficultyPickerState();
}

class _DifficultyPickerState extends State<DifficultyPicker> {
  late int _selected = widget.suggested;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.gameName, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(widget.description, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: CareSpacing.xxl),
            Text('Choose a difficulty', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CareSpacing.md),
            Wrap(
              spacing: CareSpacing.md,
              runSpacing: CareSpacing.sm,
              children: [
                for (final level in [1, 2, 3])
                  ChoiceChip(label: Text(_labels[level]!), selected: _selected == level, onSelected: (_) => setState(() => _selected = level)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              child: BigButton(label: 'Start', icon: Icons.play_arrow, onPressed: () => widget.onStart(_selected)),
            ),
          ],
        ),
      ),
    );
  }
}
