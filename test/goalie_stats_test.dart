import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/stats_service.dart';

void main() {
  group('Goalie Stats Per-Goalie and Per-Opponent Aggregation Tests', () {
    final String teamId = 'waxers_team';

    final goalie50 = Player(id: 'g50', jerseyNumber: 50, teamId: teamId, position: 'G');
    final goalie30 = Player(id: 'g30', jerseyNumber: 30, teamId: teamId, position: 'G');

    test('Verify Goalie #50 and Goalie #30 stats are separated when facing opponent shots', () {
      // Game 1 vs Capitals: Goalie 50 in net. Facing 20 shots, 2 goals allowed.
      final game1Events = List<GameEvent>.generate(18, (i) => GameEvent(
        id: 'g1_shot_$i',
        gameId: 'game_capitals_1',
        timestamp: DateTime.now(),
        period: 1,
        eventType: 'Shot',
        team: 'opponent',
        primaryPlayerId: 'opp_shooter',
        isGoal: false,
        goalieOnIceId: goalie50.id,
      ))..addAll([
        GameEvent(
          id: 'g1_goal_1',
          gameId: 'game_capitals_1',
          timestamp: DateTime.now(),
          period: 1,
          eventType: 'Shot',
          team: 'opponent',
          primaryPlayerId: 'opp_shooter',
          isGoal: true,
          goalieOnIceId: goalie50.id,
        ),
        GameEvent(
          id: 'g1_goal_2',
          gameId: 'game_capitals_1',
          timestamp: DateTime.now(),
          period: 2,
          eventType: 'Shot',
          team: 'opponent',
          primaryPlayerId: 'opp_shooter',
          isGoal: true,
          goalieOnIceId: goalie50.id,
        ),
      ]);

      // Game 2 vs Capitals: Goalie 50 in net. Facing 30 shots, 1 goal allowed.
      final game2Events = List<GameEvent>.generate(29, (i) => GameEvent(
        id: 'g2_shot_$i',
        gameId: 'game_capitals_2',
        timestamp: DateTime.now(),
        period: 1,
        eventType: 'Shot',
        team: 'opponent',
        primaryPlayerId: 'opp_shooter',
        isGoal: false,
        goalieOnIceId: goalie50.id,
      ))..add(
        GameEvent(
          id: 'g2_goal_1',
          gameId: 'game_capitals_2',
          timestamp: DateTime.now(),
          period: 3,
          eventType: 'Shot',
          team: 'opponent',
          primaryPlayerId: 'opp_shooter',
          isGoal: true,
          goalieOnIceId: goalie50.id,
        ),
      );

      // Game 3 vs Capitals: Goalie 30 in net. Facing 20 shots, 4 goals allowed.
      final game3Events = List<GameEvent>.generate(16, (i) => GameEvent(
        id: 'g3_shot_$i',
        gameId: 'game_capitals_3',
        timestamp: DateTime.now(),
        period: 1,
        eventType: 'Shot',
        team: 'opponent',
        primaryPlayerId: 'opp_shooter',
        isGoal: false,
        goalieOnIceId: goalie30.id,
      ))..addAll(List<GameEvent>.generate(4, (i) => GameEvent(
        id: 'g3_goal_$i',
        gameId: 'game_capitals_3',
        timestamp: DateTime.now(),
        period: 2,
        eventType: 'Shot',
        team: 'opponent',
        primaryPlayerId: 'opp_shooter',
        isGoal: true,
        goalieOnIceId: goalie30.id,
      )));

      final allGameEvents = [...game1Events, ...game2Events, ...game3Events];

      // Calculate stats for Goalie 50
      final stats50 = StatsService.getGoalieStats(goalie50, allGameEvents, teamId);
      expect(stats50.shotsAgainst, equals(50)); // 20 in game 1 + 30 in game 2
      expect(stats50.goalsAgainst, equals(3)); // 2 in game 1 + 1 in game 2
      expect(stats50.saves, equals(47)); // 50 - 3
      expect(stats50.gamesPlayed, equals(2));
      expect(double.parse((stats50.savePercentage * 100).toStringAsFixed(1)), equals(94.0));

      // Calculate stats for Goalie 30
      final stats30 = StatsService.getGoalieStats(goalie30, allGameEvents, teamId);
      expect(stats30.shotsAgainst, equals(20)); // 20 in game 3
      expect(stats30.goalsAgainst, equals(4)); // 4 in game 3
      expect(stats30.saves, equals(16)); // 20 - 4
      expect(stats30.gamesPlayed, equals(1));
      expect(double.parse((stats30.savePercentage * 100).toStringAsFixed(1)), equals(80.0));
    });
  });
}
