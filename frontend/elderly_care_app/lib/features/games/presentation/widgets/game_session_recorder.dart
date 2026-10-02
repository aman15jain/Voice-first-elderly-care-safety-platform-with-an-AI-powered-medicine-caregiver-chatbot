import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/games_repository.dart';
import '../../domain/game_models.dart';

/// Posts a finished round's result and refreshes the games list (so the next difficulty
/// suggestion reflects it). Shared by all four game screens instead of duplicating this
/// three-line dance in each one.
Future<void> submitGameSession(WidgetRef ref, String gameId, GameSessionResult result) async {
  await ref.read(gamesRepositoryProvider).recordSession(gameId, result);
  ref.invalidate(gamesListProvider);
}
