import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/stats_service.dart';

void main() {
  group('Power Play Tracking Tests', () {
    const String teamId = 'waxers_team';
    const String gameId = 'game_167';

    test('3 Power Plays, all unsuccessful, tracking shots and opportunities correctly', () {
      final events = <GameEvent>[
        // PP Opportunity 1 (Opponent penalty) + 1 PP shot (no goal)
        GameEvent(
          id: 'p1_opp_pen',
          gameId: gameId,
          timestamp: DateTime.now(),
          period: 1,
          eventType: 'Penalty',
          team: 'opponent',
          primaryPlayerId: '',
          penaltyType: 'Unspecified',
          penaltyDuration: 2,
        ),
        GameEvent(
          id: 'p1_pp_shot',
          gameId: gameId,
          timestamp: DateTime.now(),
          period: 1,
          eventType: 'Shot',
          team: teamId,
          primaryPlayerId: 'player_1',
          isGoal: false,
          goalSituation: GoalSituation.powerPlay,
        ),

        // PP Opportunity 2 (Opponent penalty) + 2 PP shots (no goal)
        GameEvent(
          id: 'p2_opp_pen',
          gameId: gameId,
          timestamp: DateTime.now(),
          period: 2,
          eventType: 'Penalty',
          team: 'opponent',
          primaryPlayerId: '',
          penaltyType: 'Unspecified',
          penaltyDuration: 2,
        ),
        GameEvent(
          id: 'p2_pp_shot1',
          gameId: gameId,
          timestamp: DateTime.now(),
          period: 2,
          eventType: 'Shot',
          team: teamId,
          primaryPlayerId: 'player_2',
          isGoal: false,
          goalSituation: GoalSituation.powerPlay,
        ),
        GameEvent(
          id: 'p2_pp_shot2',
          gameId: gameId,
          timestamp: DateTime.now(),
          period: 2,
          eventType: 'Shot',
          team: teamId,
          primaryPlayerId: 'player_1',
          isGoal: false,
          goalSituation: GoalSituation.powerPlay,
        ),

        // PP Opportunity 3 (Opponent penalty) + 0 shots
        GameEvent(
          id: 'p3_opp_pen',
          gameId: gameId,
          timestamp: DateTime.now(),
          period: 3,
          eventType: 'Penalty',
          team: 'opponent',
          primaryPlayerId: '',
          penaltyType: 'Unspecified',
          penaltyDuration: 2,
        ),
      ];

      final stStats = StatsService.getSpecialTeamsStats(events, teamId);

      expect(stStats.ppOpportunities, equals(3), reason: 'Should have 3 Power Play opportunities');
      expect(stStats.ppGoals, equals(0), reason: 'Should have 0 Power Play goals (0/3)');
      expect(stStats.ppPercentage, equals(0.0), reason: 'PP% should be 0.0%');
      expect(stStats.ppShots, equals(3), reason: 'Should have 3 PP shots total');
      expect(stStats.ppShotsPerOpp, equals(1.0), reason: '3 shots / 3 opportunities = 1.0 shot/PP');
    });

    test('Situation toggling logic: tapping active PP mode toggles back to Even Strength', () {
      GoalSituation currentSituation = GoalSituation.evenStrength;

      GoalSituation changeSituation(GoalSituation newSituation) {
        final targetSituation = (currentSituation == newSituation && newSituation != GoalSituation.evenStrength)
            ? GoalSituation.evenStrength
            : newSituation;
        currentSituation = targetSituation;
        return targetSituation;
      }

      // 1. Turn PP Mode ON
      expect(changeSituation(GoalSituation.powerPlay), equals(GoalSituation.powerPlay));
      expect(currentSituation, equals(GoalSituation.powerPlay));

      // 2. Turn PP Mode OFF by tapping PP Mode again
      expect(changeSituation(GoalSituation.powerPlay), equals(GoalSituation.evenStrength));
      expect(currentSituation, equals(GoalSituation.evenStrength));

      // 3. Turn PK Mode ON
      expect(changeSituation(GoalSituation.shortHanded), equals(GoalSituation.shortHanded));
      expect(currentSituation, equals(GoalSituation.shortHanded));

      // 4. Turn PK Mode OFF by tapping PK Mode again
      expect(changeSituation(GoalSituation.shortHanded), equals(GoalSituation.evenStrength));
      expect(currentSituation, equals(GoalSituation.evenStrength));
    });
  });
}
