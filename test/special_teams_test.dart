import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/stats_service.dart';

void main() {
  group('Special Teams & On-Ice Stats Calculations', () {
    const String teamId = 'my_team';

    final player88 = Player(id: 'p88', jerseyNumber: 88, teamId: teamId, position: 'C');
    final player19 = Player(id: 'p19', jerseyNumber: 19, teamId: teamId, position: 'LW');
    final goalie1 = Player(id: 'g1', jerseyNumber: 1, teamId: teamId, position: 'G');

    test('Special Teams PP%, PK%, Shots/PP, and Net ST Goals calculation', () {
      final events = <GameEvent>[
        // Opponent Penalties = 3 PP opportunities for my team
        GameEvent(id: 'e1', gameId: 'g1', timestamp: DateTime.now(), period: 1, eventType: 'Penalty', team: 'opponent', primaryPlayerId: 'opp1'),
        GameEvent(id: 'e2', gameId: 'g1', timestamp: DateTime.now(), period: 1, eventType: 'Penalty', team: 'opponent', primaryPlayerId: 'opp2'),
        GameEvent(id: 'e3', gameId: 'g1', timestamp: DateTime.now(), period: 2, eventType: 'Penalty', team: 'opponent', primaryPlayerId: 'opp3'),

        // My Team Penalties = 2 PK opportunities
        GameEvent(id: 'e4', gameId: 'g1', timestamp: DateTime.now(), period: 2, eventType: 'Penalty', team: teamId, primaryPlayerId: player88.id),
        GameEvent(id: 'e5', gameId: 'g1', timestamp: DateTime.now(), period: 3, eventType: 'Penalty', team: teamId, primaryPlayerId: player19.id),

        // Shots on PP by my team
        GameEvent(id: 'e6', gameId: 'g1', timestamp: DateTime.now(), period: 1, eventType: 'Shot', team: teamId, primaryPlayerId: player88.id, isGoal: false, goalSituation: GoalSituation.powerPlay),
        GameEvent(id: 'e7', gameId: 'g1', timestamp: DateTime.now(), period: 1, eventType: 'Shot', team: teamId, primaryPlayerId: player19.id, isGoal: true, goalSituation: GoalSituation.powerPlay),
        GameEvent(id: 'e8', gameId: 'g1', timestamp: DateTime.now(), period: 2, eventType: 'Shot', team: teamId, primaryPlayerId: player88.id, isGoal: false, goalSituation: GoalSituation.powerPlay),

        // Opponent shots on PK
        GameEvent(id: 'e9', gameId: 'g1', timestamp: DateTime.now(), period: 2, eventType: 'Shot', team: 'opponent', primaryPlayerId: 'opp1', isGoal: false, goalSituation: GoalSituation.powerPlay, goalieOnIceId: goalie1.id),

        // Short-Handed goal for my team
        GameEvent(id: 'e10', gameId: 'g1', timestamp: DateTime.now(), period: 3, eventType: 'Shot', team: teamId, primaryPlayerId: player88.id, isGoal: true, goalSituation: GoalSituation.shortHanded),
      ];

      final stStats = StatsService.getSpecialTeamsStats(events, teamId);

      expect(stStats.ppGoals, equals(1));
      expect(stStats.ppOpportunities, equals(3));
      expect(double.parse(stStats.ppPercentage.toStringAsFixed(1)), equals(33.3));
      expect(stStats.ppShots, equals(3));
      expect(stStats.ppShotsPerOpp, equals(1.0));

      expect(stStats.pkOpportunities, equals(2));
      expect(stStats.pkGoalsConceded, equals(0));
      expect(stStats.pkSuccesses, equals(2));
      expect(stStats.pkPercentage, equals(100.0));

      expect(stStats.shGoalsFor, equals(1));
      expect(stStats.netSpecialTeamsGoals, equals(2)); // 1 PPG + 1 SHGF - 0 PPGA
      expect(double.parse(stStats.combinedSpecialTeamsIndex.toStringAsFixed(1)), equals(133.3));
      expect(stStats.netPenalties, equals(1)); // 3 penalties drawn - 2 taken
    });

    test('Penalty Kill goal conceded reduces pkSuccesses', () {
      final events = <GameEvent>[
        // 2 PK Opportunities
        GameEvent(id: 'pk1', gameId: 'g1', timestamp: DateTime.now(), period: 1, eventType: 'Penalty', team: teamId, primaryPlayerId: player88.id),
        GameEvent(id: 'pk2', gameId: 'g1', timestamp: DateTime.now(), period: 2, eventType: 'Penalty', team: teamId, primaryPlayerId: player19.id),

        // Opponent Goal on PK logged as GoalSituation.shortHanded
        GameEvent(id: 'g_opp', gameId: 'g1', timestamp: DateTime.now(), period: 1, eventType: 'Shot', team: 'opponent', primaryPlayerId: 'opp1', isGoal: true, goalSituation: GoalSituation.shortHanded),
      ];

      final stStats = StatsService.getSpecialTeamsStats(events, teamId);

      expect(stStats.pkOpportunities, equals(2));
      expect(stStats.pkGoalsConceded, equals(1));
      expect(stStats.pkSuccesses, equals(1)); // 2 PKs - 1 Goal Conceded = 1 Success
      expect(stStats.pkPercentage, equals(50.0));
    });

    test('On-ice shot differential (Player Corsi) calculation', () {
      final events = <GameEvent>[
        GameEvent(
          id: 'e1',
          gameId: 'g1',
          timestamp: DateTime.now(),
          period: 1,
          eventType: 'Shot',
          team: teamId,
          primaryPlayerId: player88.id,
          isGoal: false,
          yourTeamPlayersOnIce: [player88.id, player19.id],
        ),
        GameEvent(
          id: 'e2',
          gameId: 'g1',
          timestamp: DateTime.now(),
          period: 1,
          eventType: 'Shot',
          team: teamId,
          primaryPlayerId: player19.id,
          isGoal: true,
          yourTeamPlayersOnIce: [player88.id, player19.id],
        ),
        GameEvent(
          id: 'e3',
          gameId: 'g1',
          timestamp: DateTime.now(),
          period: 2,
          eventType: 'Shot',
          team: 'opponent',
          primaryPlayerId: 'opp1',
          isGoal: false,
          yourTeamPlayersOnIce: [player88.id],
        ),
      ];

      final corsi88 = StatsService.getOnIceShotStats(player88, events, teamId);
      expect(corsi88.shotsForOnIce, equals(2));
      expect(corsi88.shotsAgainstOnIce, equals(1));
      expect(corsi88.netShotsOnIce, equals(1));
      expect(double.parse(corsi88.shotSharePercentage.toStringAsFixed(1)), equals(66.7));

      final corsi19 = StatsService.getOnIceShotStats(player19, events, teamId);
      expect(corsi19.shotsForOnIce, equals(2));
      expect(corsi19.shotsAgainstOnIce, equals(0));
      expect(corsi19.netShotsOnIce, equals(2));
      expect(corsi19.shotSharePercentage, equals(100.0));
    });
  });
}
