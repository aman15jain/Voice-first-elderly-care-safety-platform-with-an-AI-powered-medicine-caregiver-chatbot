import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/game_models.dart';

class GamesRepository {
  GamesRepository(this._dio);
  final Dio _dio;

  Future<List<CognitiveGame>> listGames() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/games');
    return (res.data!['games'] as List).map((e) => CognitiveGame.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> recordSession(String gameId, GameSessionResult result) {
    return _dio.post<void>('/api/games/$gameId/session', data: result.toJson());
  }
}

final gamesRepositoryProvider = Provider<GamesRepository>((ref) => GamesRepository(ref.watch(dioProvider)));

final gamesListProvider = FutureProvider.autoDispose<List<CognitiveGame>>((ref) {
  return ref.watch(gamesRepositoryProvider).listGames();
});
