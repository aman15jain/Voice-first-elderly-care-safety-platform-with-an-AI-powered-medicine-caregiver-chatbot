import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/care/care_pill.dart';
import '../../../core/theme/care_tokens.dart';
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
            padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, CareSpacing.xl),
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
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(_gameRoutes[game.type]!, extra: game),
        child: Padding(
          padding: const EdgeInsets.all(CareSpacing.lg + 2),
          child: Row(
            children: [
              CareIconTile(icon: _gameIcons[game.type] ?? Icons.extension, color: CareColors.accentViolet, background: CareColors.accentVioletSoft, size: 56),
              const SizedBox(width: CareSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(game.description, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 30, color: CareColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
