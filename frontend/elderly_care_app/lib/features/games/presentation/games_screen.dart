import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../data/games_repository.dart';
import '../domain/game_models.dart';

const _gameRoutes = {
  GameType.memoryMatch: '/games/memory-match',
  GameType.patternRecognition: '/games/pattern-recognition',
  GameType.attentionExercise: '/games/attention-exercise',
  GameType.sequenceRecall: '/games/sequence-recall',
};

const _gameIcons = {
  GameType.memoryMatch: Icons.grid_view,
  GameType.patternRecognition: Icons.pattern,
  GameType.attentionExercise: Icons.center_focus_strong,
  GameType.sequenceRecall: Icons.repeat,
};

class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(gamesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cognitive Games')),
      body: SafeArea(
        child: games.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(gamesListProvider)),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _GameCard(game: list[i]),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final CognitiveGame game;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(_gameRoutes[game.type]!, extra: game),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(_gameIcons[game.type], size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(game.description, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
