import 'package:elderly_care_app/features/games/domain/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gameTypeFromString maps every backend type', () {
    expect(gameTypeFromString('MEMORY_MATCH'), GameType.memoryMatch);
    expect(gameTypeFromString('PATTERN_RECOGNITION'), GameType.patternRecognition);
    expect(gameTypeFromString('ATTENTION_EXERCISE'), GameType.attentionExercise);
    expect(gameTypeFromString('SEQUENCE_RECALL'), GameType.sequenceRecall);
  });

  test('CognitiveGame.fromJson parses the suggested difficulty', () {
    final game = CognitiveGame.fromJson({
      'id': 'g1',
      'type': 'MEMORY_MATCH',
      'name': 'Memory Match',
      'description': 'Find the pairs',
      'suggestedDifficulty': 2,
    });
    expect(game.type, GameType.memoryMatch);
    expect(game.suggestedDifficulty, 2);
  });

  test('GameSessionResult.toJson sends exactly the fields the backend expects', () {
    const result = GameSessionResult(difficulty: 2, score: 150, mistakes: 1, durationSeconds: 42, completed: true);
    expect(result.toJson(), {'difficulty': 2, 'score': 150, 'mistakes': 1, 'durationSeconds': 42, 'completed': true});
  });
}
