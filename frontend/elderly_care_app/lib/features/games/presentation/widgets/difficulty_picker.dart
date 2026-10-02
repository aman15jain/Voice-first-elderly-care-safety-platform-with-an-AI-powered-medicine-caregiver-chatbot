import 'package:flutter/material.dart';

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
            Text(widget.description, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            const Text('Choose a difficulty', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                for (final level in [1, 2, 3])
                  ChoiceChip(
                    label: Text(_labels[level]!, style: const TextStyle(fontSize: 18)),
                    selected: _selected == level,
                    onSelected: (_) => setState(() => _selected = level),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(width: 220, child: BigButton(label: 'Start', icon: Icons.play_arrow, onPressed: () => widget.onStart(_selected))),
          ],
        ),
      ),
    );
  }
}
