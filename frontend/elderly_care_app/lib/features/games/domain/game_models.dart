enum GameType { memoryMatch, patternRecognition, attentionExercise, sequenceRecall }

GameType gameTypeFromString(String value) {
  switch (value) {
    case 'MEMORY_MATCH':
      return GameType.memoryMatch;
    case 'PATTERN_RECOGNITION':
      return GameType.patternRecognition;
    case 'ATTENTION_EXERCISE':
      return GameType.attentionExercise;
    case 'SEQUENCE_RECALL':
      return GameType.sequenceRecall;
    default:
      return GameType.memoryMatch;
  }
}

class CognitiveGame {
  const CognitiveGame({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.suggestedDifficulty,
  });

  final String id;
  final GameType type;
  final String name;
  final String description;
  final int suggestedDifficulty;

  factory CognitiveGame.fromJson(Map<String, dynamic> json) => CognitiveGame(
    id: json['id'] as String,
    type: gameTypeFromString(json['type'] as String),
    name: json['name'] as String,
    description: json['description'] as String,
    suggestedDifficulty: json['suggestedDifficulty'] as int,
  );
}

/// The result of one played round, computed entirely on-device by the game itself.
class GameSessionResult {
  const GameSessionResult({
    required this.difficulty,
    required this.score,
    required this.mistakes,
    required this.durationSeconds,
    required this.completed,
  });

  final int difficulty;
  final int score;
  final int mistakes;
  final int durationSeconds;
  final bool completed;

  Map<String, dynamic> toJson() => {
    'difficulty': difficulty,
    'score': score,
    'mistakes': mistakes,
    'durationSeconds': durationSeconds,
    'completed': completed,
  };
}
