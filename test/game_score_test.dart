import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/game_score.dart';

GameEvent ev(
  String id,
  String gameId,
  String eventType,
  String team, {
  bool? isGoal,
  String player = 'player_1',
  String? penaltyType,
}) {
  return GameEvent(
    id: id,
    gameId: gameId,
    timestamp: DateTime(2026, 1, 1),
    period: 1,
    eventType: eventType,
    team: team,
    primaryPlayerId: player,
    isGoal: isGoal,
    penaltyType: penaltyType,
  );
}

void main() {
  const teamId = 'waxersu13a';

  group('gameScoresByGameId', () {
    test('win: our goals vs opponent goals, non-goal shots ignored', () {
      final scores = gameScoresByGameId([
        ev('1', 'g1', 'Shot', teamId, isGoal: true),
        ev('2', 'g1', 'Shot', teamId, isGoal: true),
        ev('3', 'g1', 'Shot', teamId, isGoal: true),
        ev('4', 'g1', 'Shot', teamId, isGoal: false),
        ev('5', 'g1', 'Shot', 'opponent', isGoal: true),
        ev('6', 'g1', 'Shot', 'opponent', isGoal: false),
      ], teamId);
      final s = scores['g1']!;
      expect(s.goalsFor, 3);
      expect(s.goalsAgainst, 1);
      expect(s.isWin, isTrue);
      expect(s.label, 'W 3\u20131');
    });

    test('loss', () {
      final scores = gameScoresByGameId([
        ev('1', 'g1', 'Shot', teamId, isGoal: true),
        ev('2', 'g1', 'Shot', 'opponent', isGoal: true),
        ev('3', 'g1', 'Shot', 'opponent', isGoal: true),
      ], teamId);
      final s = scores['g1']!;
      expect(s.isLoss, isTrue);
      expect(s.label, 'L 1\u20132');
    });

    test('tie with goals', () {
      final scores = gameScoresByGameId([
        ev('1', 'g1', 'Shot', teamId, isGoal: true),
        ev('2', 'g1', 'Shot', 'opponent', isGoal: true),
      ], teamId);
      expect(scores['g1']!.isTie, isTrue);
      expect(scores['g1']!.label, 'T 1\u20131');
    });

    test('shots but no goals is a real 0-0 tie, not absent', () {
      final scores = gameScoresByGameId([
        ev('1', 'g1', 'Shot', teamId, isGoal: false),
        ev('2', 'g1', 'Shot', 'opponent', isGoal: false),
      ], teamId);
      expect(scores['g1'], isNotNull);
      expect(scores['g1']!.label, 'T 0\u20130');
    });

    test('penalty-only game (incl. a PP marker) scores 0-0, markers are not goals', () {
      final scores = gameScoresByGameId([
        ev('1', 'g1', 'Penalty', teamId,
            player: 'player_9', penaltyType: 'Tripping'),
        ev('2', 'g1', 'Penalty', 'opponent',
            player: '', penaltyType: 'Unspecified'),
      ], teamId);
      expect(scores['g1']!.goalsFor, 0);
      expect(scores['g1']!.goalsAgainst, 0);
      expect(scores['g1']!.isTie, isTrue);
    });

    test('a game with no logged events is absent (no chip, not a 0-0 tie)', () {
      final scores = gameScoresByGameId([
        ev('1', 'g1', 'Shot', teamId, isGoal: true),
      ], teamId);
      expect(scores.containsKey('g2'), isFalse);
      expect(scores['g2'], isNull);
    });

    test('events from other games do not leak into a game\'s score', () {
      final scores = gameScoresByGameId([
        ev('1', 'g1', 'Shot', teamId, isGoal: true),
        ev('2', 'g2', 'Shot', 'opponent', isGoal: true),
        ev('3', 'g2', 'Shot', 'opponent', isGoal: true),
      ], teamId);
      expect(scores['g1']!.label, 'W 1\u20130');
      expect(scores['g2']!.label, 'L 0\u20132');
    });
  });
}
