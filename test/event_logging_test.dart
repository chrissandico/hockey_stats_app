import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/stats_service.dart';

void main() {
  group('Core Event Logging & Stats Verification Tests', () {
    final String teamId = 'waxers_team';
    final String gameId = 'game_001';

    final player1 = Player(id: 'p1', jerseyNumber: 19, teamId: teamId, position: 'C');
    final player2 = Player(id: 'p2', jerseyNumber: 8, teamId: teamId, position: 'LW');
    final player3 = Player(id: 'p3', jerseyNumber: 29, teamId: teamId, position: 'RW');
    final goalie = Player(id: 'g1', jerseyNumber: 31, teamId: teamId, position: 'G');

    test('Log Goal Event and verify Goal, Assist, Point, and +/- calculations', () {
      final goalEvent = GameEvent(
        id: 'evt_goal_1',
        gameId: gameId,
        timestamp: DateTime.now(),
        period: 1,
        eventType: 'Shot',
        team: teamId,
        primaryPlayerId: player1.id, // Scorer
        assistPlayer1Id: player2.id, // Assist 1
        assistPlayer2Id: player3.id, // Assist 2
        isGoal: true,
        goalSituation: GoalSituation.evenStrength,
        yourTeamPlayersOnIce: ['p1', 'p2', 'p3'],
        gameClockTime: '14:22',
      );

      final events = [goalEvent];

      // Scorer
      expect(StatsService.calculateGoals(player1, events), equals(1));
      expect(StatsService.calculateAssists(player1, events), equals(0));
      expect(StatsService.calculatePoints(player1, events), equals(1));
      expect(StatsService.calculatePlusMinus(player1, events, teamId), equals(1));

      // Assist 1
      expect(StatsService.calculateGoals(player2, events), equals(0));
      expect(StatsService.calculateAssists(player2, events), equals(1));
      expect(StatsService.calculatePoints(player2, events), equals(1));
      expect(StatsService.calculatePlusMinus(player2, events, teamId), equals(1));

      // Assist 2
      expect(StatsService.calculateGoals(player3, events), equals(0));
      expect(StatsService.calculateAssists(player3, events), equals(1));
      expect(StatsService.calculatePoints(player3, events), equals(1));
      expect(StatsService.calculatePlusMinus(player3, events, teamId), equals(1));
    });

    test('Log Penalty Event and verify Penalty Minutes calculation', () {
      final penaltyEvent = GameEvent(
        id: 'evt_pen_1',
        gameId: gameId,
        timestamp: DateTime.now(),
        period: 2,
        eventType: 'Penalty',
        team: teamId,
        primaryPlayerId: player1.id,
        penaltyType: 'Tripping',
        penaltyDuration: 2,
        yourTeamPlayersOnIce: ['p1', 'p2', 'p3'],
        gameClockTime: '08:15',
      );

      final events = [penaltyEvent];

      expect(StatsService.calculatePenaltyMinutes(player1, events), equals(2));
      expect(StatsService.calculatePenaltyMinutes(player2, events), equals(0));
    });
  });
}
