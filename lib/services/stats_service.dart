import 'package:hockey_stats_app/models/data_models.dart';
import 'dart:math';

class SpecialTeamsStats {
  final int ppGoals;
  final int ppOpportunities;
  final double ppPercentage;
  final int pkOpportunities;
  final int pkGoalsConceded;
  final int pkSuccesses;
  final double pkPercentage;
  final int shGoalsFor;
  final int shGoalsAgainst;
  final int ppShots;
  final double ppShotsPerOpp;
  final int pkShotsAllowed;
  final double pkShotsAllowedPerOpp;
  final int netSpecialTeamsGoals;
  final double combinedSpecialTeamsIndex;
  final int penaltiesDrawn;
  final int penaltiesTaken;
  final int netPenalties;

  SpecialTeamsStats({
    required this.ppGoals,
    required this.ppOpportunities,
    required this.ppPercentage,
    required this.pkOpportunities,
    required this.pkGoalsConceded,
    required this.pkSuccesses,
    required this.pkPercentage,
    required this.shGoalsFor,
    required this.shGoalsAgainst,
    required this.ppShots,
    required this.ppShotsPerOpp,
    required this.pkShotsAllowed,
    required this.pkShotsAllowedPerOpp,
    required this.netSpecialTeamsGoals,
    required this.combinedSpecialTeamsIndex,
    required this.penaltiesDrawn,
    required this.penaltiesTaken,
    required this.netPenalties,
  });
}

class OnIceShotStats {
  final int shotsForOnIce;
  final int shotsAgainstOnIce;
  final int netShotsOnIce;
  final double shotSharePercentage;

  OnIceShotStats({
    required this.shotsForOnIce,
    required this.shotsAgainstOnIce,
    required this.netShotsOnIce,
    required this.shotSharePercentage,
  });
}

class StatsService {
  /// Calculates plus/minus for a player based on the 3-rule system:
  /// Rule 1: Power Play Goal (Scoring team has advantage) → No +/- awarded
  /// Rule 2: Even Strength Goal (Equal players) → Normal +/- awarded  
  /// Rule 3: Short-Handed Goal (Scoring team at disadvantage) → Normal +/- awarded
  static int calculatePlusMinus(Player player, List<GameEvent> gameEvents, String teamId) {
    // Skip plus/minus calculation for goalies
    if (player.position == 'G') {
      return 0;
    }
    
    int plusMinus = 0;

    // Calculate plus/minus for when the player is on the ice when a goal is scored
    for (var event in gameEvents) {
      if (event.eventType == 'Shot' && event.isGoal == true) {
        // CANONICAL RULE (WEB_APP_STATS_SPEC.md, Column K + +/- table):
        // +/- is awarded only when the SCORING team was at even strength or
        // short-handed; a goal scored by a team on its own power play awards
        // nothing. goalSituation records OUR team's manpower state, so the
        // scorer's state depends on who scored:
        //   our PP goal  (powerPlay stamp, our goal)     -> skip
        //   our SH goal  (shortHanded stamp, our goal)   -> +1
        //   their PP goal (shortHanded stamp, their goal) -> skip
        //   their SH goal (powerPlay stamp, their goal)   -> -1
        //   even strength, or situation not recorded (null) -> award
        final scoredByYourTeam = event.team == teamId;
        final scorerHadPowerPlay = scoredByYourTeam
            ? event.goalSituation == GoalSituation.powerPlay
            : event.goalSituation == GoalSituation.shortHanded;
        if (scorerHadPowerPlay) {
          continue;
        }

        if (!_wasPlayerOnIce(player, event, teamId)) {
          continue;
        }
        if (scoredByYourTeam) {
          plusMinus++;
        } else {
          plusMinus--;
        }
      }
    }

    return plusMinus;
  }

  /// Helper method to determine if a player was on ice during a goal
  static bool _wasPlayerOnIce(Player player, GameEvent event, String teamId) {
    if (event.team == teamId) {
      // For your team's goals, check players on ice or involvement in the play
      if (event.yourTeamPlayersOnIce != null && event.yourTeamPlayersOnIce!.isNotEmpty) {
        return event.yourTeamPlayersOnIce!.contains(player.id);
      } else {
        // Fallback: if no players on ice data, check if player was involved in the play
        return event.primaryPlayerId == player.id || 
               event.assistPlayer1Id == player.id || 
               event.assistPlayer2Id == player.id;
      }
    } else {
      // For opponent goals (any team value other than teamId), check if player was on ice for your team
      if (event.yourTeamPlayersOnIce != null && event.yourTeamPlayersOnIce!.isNotEmpty) {
        return event.yourTeamPlayersOnIce!.contains(player.id);
      }
      // If no players on ice data for opponent goals, we can't determine plus/minus
      return false;
    }
  }

  /// Calculate goals for a player
  static int calculateGoals(Player player, List<GameEvent> gameEvents) {
    return gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.primaryPlayerId == player.id
    ).length;
  }

  /// Calculate assists for a player
  static int calculateAssists(Player player, List<GameEvent> gameEvents) {
    return gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      (event.assistPlayer1Id == player.id || event.assistPlayer2Id == player.id)
    ).length;
  }

  /// Calculate points (goals + assists) for a player
  static int calculatePoints(Player player, List<GameEvent> gameEvents) {
    return calculateGoals(player, gameEvents) + calculateAssists(player, gameEvents);
  }

  /// Calculate penalty minutes for a player
  static int calculatePenaltyMinutes(Player player, List<GameEvent> gameEvents) {
    return gameEvents
      .where((event) => event.eventType == 'Penalty' && event.primaryPlayerId == player.id)
      .map((event) => event.penaltyDuration ?? 0)
      .fold(0, (a, b) => a + b);
  }

  /// Calculate shots for a player
  static int calculateShots(Player player, List<GameEvent> gameEvents) {
    return gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.primaryPlayerId == player.id
    ).length;
  }

  /// Calculate shooting percentage (SH%) for a player
  static double calculateShootingPercentage(Player player, List<GameEvent> gameEvents) {
    final shots = calculateShots(player, gameEvents);
    if (shots == 0) return 0.0;
    final goals = calculateGoals(player, gameEvents);
    return (goals / shots) * 100;
  }

  /// Get complete player statistics
  static PlayerSeasonStats getPlayerStats(Player player, List<GameEvent> gameEvents, String teamId) {
    return PlayerSeasonStats(
      playerId: player.id,
      playerName: '', // This would be set elsewhere if needed
      playerJerseyNumber: player.jerseyNumber,
      playerPosition: player.position,
      goals: calculateGoals(player, gameEvents),
      assists: calculateAssists(player, gameEvents),
      shots: calculateShots(player, gameEvents),
      penaltyMinutes: calculatePenaltyMinutes(player, gameEvents),
      plusMinus: calculatePlusMinus(player, gameEvents, teamId),
    );
  }

  /// Calculate shots against for a goalie
  static int calculateShotsAgainst(
    Player goalie,
    List<GameEvent> gameEvents,
    String teamId, {
    List<Player>? teamGoalies,
  }) {
    if (goalie.position != 'G') return 0;
    final isOnlyGoalie = teamGoalies != null &&
        teamGoalies.length == 1 &&
        teamGoalies.first.id == goalie.id;

    return gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.team != teamId && // Opponent shots
      (event.goalieOnIceId == goalie.id ||
          (isOnlyGoalie && (event.goalieOnIceId == null || event.goalieOnIceId!.isEmpty)))
    ).length;
  }

  /// Calculate goals against for a goalie
  static int calculateGoalsAgainst(
    Player goalie,
    List<GameEvent> gameEvents,
    String teamId, {
    List<Player>? teamGoalies,
  }) {
    if (goalie.position != 'G') return 0;
    final isOnlyGoalie = teamGoalies != null &&
        teamGoalies.length == 1 &&
        teamGoalies.first.id == goalie.id;

    return gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true &&
      event.team != teamId && // Opponent goals
      (event.goalieOnIceId == goalie.id ||
          (isOnlyGoalie && (event.goalieOnIceId == null || event.goalieOnIceId!.isEmpty)))
    ).length;
  }

  /// Calculate saves for a goalie
  static int calculateSaves(
    Player goalie,
    List<GameEvent> gameEvents,
    String teamId, {
    List<Player>? teamGoalies,
  }) {
    if (goalie.position != 'G') return 0;
    
    final shotsAgainst = calculateShotsAgainst(goalie, gameEvents, teamId, teamGoalies: teamGoalies);
    final goalsAgainst = calculateGoalsAgainst(goalie, gameEvents, teamId, teamGoalies: teamGoalies);
    return shotsAgainst - goalsAgainst;
  }

  /// Calculate save percentage for a goalie
  static double calculateSavePercentage(
    Player goalie,
    List<GameEvent> gameEvents,
    String teamId, {
    List<Player>? teamGoalies,
  }) {
    if (goalie.position != 'G') return 0.0;
    
    final shotsAgainst = calculateShotsAgainst(goalie, gameEvents, teamId, teamGoalies: teamGoalies);
    if (shotsAgainst == 0) return 0.0;
    
    final saves = calculateSaves(goalie, gameEvents, teamId, teamGoalies: teamGoalies);
    return saves / shotsAgainst;
  }

  /// Calculate games played for a goalie
  static int calculateGamesPlayed(
    Player goalie,
    List<GameEvent> gameEvents, {
    List<Player>? teamGoalies,
  }) {
    if (goalie.position != 'G') return 0;
    
    final isOnlyGoalie = teamGoalies != null &&
        teamGoalies.length == 1 &&
        teamGoalies.first.id == goalie.id;

    // Count unique games where the goalie was on ice
    final uniqueGames = gameEvents
        .where((event) =>
            event.goalieOnIceId == goalie.id ||
            (isOnlyGoalie && (event.goalieOnIceId == null || event.goalieOnIceId!.isEmpty)))
        .map((event) => event.gameId)
        .toSet();
    
    return uniqueGames.length;
  }

  /// Get complete goalie statistics
  static GoalieSeasonStats getGoalieStats(
    Player goalie,
    List<GameEvent> gameEvents,
    String teamId, {
    List<Player>? teamGoalies,
  }) {
    if (goalie.position != 'G') {
      return GoalieSeasonStats(playerId: goalie.id);
    }
    
    final stats = GoalieSeasonStats(
      playerId: goalie.id,
      playerName: '#${goalie.jerseyNumber}',
      playerJerseyNumber: goalie.jerseyNumber,
      shotsAgainst: calculateShotsAgainst(goalie, gameEvents, teamId, teamGoalies: teamGoalies),
      goalsAgainst: calculateGoalsAgainst(goalie, gameEvents, teamId, teamGoalies: teamGoalies),
      gamesPlayed: calculateGamesPlayed(goalie, gameEvents, teamGoalies: teamGoalies),
    );
    
    final isOnlyGoalie = teamGoalies != null &&
        teamGoalies.length == 1 &&
        teamGoalies.first.id == goalie.id;

    // Add games played tracking
    final uniqueGames = gameEvents
        .where((event) =>
            event.goalieOnIceId == goalie.id ||
            (isOnlyGoalie && (event.goalieOnIceId == null || event.goalieOnIceId!.isEmpty)))
        .map((event) => event.gameId)
        .toSet();
    
    for (final gameId in uniqueGames) {
      stats.addGamePlayed(gameId);
    }
    
    return stats;
  }

  /// Calculates complete special teams statistics (PP%, PK%, Shots/PP, Shots Allowed/PK, Net ST Goals)
  static SpecialTeamsStats getSpecialTeamsStats(List<GameEvent> gameEvents, String teamId) {
    int ppGoals = 0;
    int rawPpOpps = 0;
    int pkGoalsConceded = 0;
    int rawPkOpps = 0;
    int shGoalsFor = 0;
    int shGoalsAgainst = 0;
    int ppShots = 0;
    int pkShotsAllowed = 0;

    for (final event in gameEvents) {
      final isYourTeam = event.team == teamId;

      // CANONICAL DEFINITION (WEB_APP_STATS_SPEC.md, Column K): goalSituation is
      // OUR team's manpower state, independent of who the event belongs to:
      //   powerPlay   = WE have the advantage
      //   shortHanded = WE are short-handed ("Penalty Kill" in the Sheet)
      // An opponent goal stamped powerPlay is a SHORT-HANDED goal against (they
      // scored while we had the power play) — never a PK concession — and an
      // opponent goal stamped shortHanded is their POWER-PLAY goal.
      if (event.eventType == 'Shot') {
        if (event.isGoal == true) {
          if (event.goalSituation == GoalSituation.powerPlay) {
            if (isYourTeam) {
              ppGoals++;
            } else {
              shGoalsAgainst++;
            }
          } else if (event.goalSituation == GoalSituation.shortHanded) {
            if (isYourTeam) {
              shGoalsFor++;
            } else {
              pkGoalsConceded++;
            }
          }
        }

        // Shot counts on power play / penalty kill
        if (event.goalSituation == GoalSituation.powerPlay) {
          if (isYourTeam) {
            ppShots++;
          }
          // Opponent shots while WE have the power play are short-handed shots
          // against — they are NOT shots allowed on our penalty kill.
        } else if (event.goalSituation == GoalSituation.shortHanded) {
          if (!isYourTeam) {
            pkShotsAllowed++;
          }
        }
      } else if (event.eventType == 'Penalty') {
        if (isYourTeam) {
          rawPkOpps++;
        } else {
          rawPpOpps++;
        }
      }
    }

    // Ensure opportunities account for PP goals scored/conceded even if penalties weren't logged explicitly
    final ppOpps = max(rawPpOpps, ppGoals);
    final pkOpps = max(rawPkOpps, pkGoalsConceded);

    final ppPct = ppOpps > 0 ? (ppGoals / ppOpps) * 100 : 0.0;
    final pkSuccesses = pkOpps - pkGoalsConceded;
    final pkPct = pkOpps > 0 ? (pkSuccesses / pkOpps) * 100 : 100.0;

    final ppShotsPerOpp = ppOpps > 0 ? ppShots / ppOpps : 0.0;
    final pkShotsAllowedPerOpp = pkOpps > 0 ? pkShotsAllowed / pkOpps : 0.0;

    final netStGoals = (ppGoals + shGoalsFor) - (pkGoalsConceded + shGoalsAgainst);
    final combinedStIndex = ppPct + pkPct;

    final penaltiesTaken = rawPkOpps;
    final penaltiesDrawn = rawPpOpps;
    final netPenalties = penaltiesDrawn - penaltiesTaken;

    return SpecialTeamsStats(
      ppGoals: ppGoals,
      ppOpportunities: ppOpps,
      ppPercentage: ppPct,
      pkOpportunities: pkOpps,
      pkGoalsConceded: pkGoalsConceded,
      pkSuccesses: pkSuccesses,
      pkPercentage: pkPct,
      shGoalsFor: shGoalsFor,
      shGoalsAgainst: shGoalsAgainst,
      ppShots: ppShots,
      ppShotsPerOpp: ppShotsPerOpp,
      pkShotsAllowed: pkShotsAllowed,
      pkShotsAllowedPerOpp: pkShotsAllowedPerOpp,
      netSpecialTeamsGoals: netStGoals,
      combinedSpecialTeamsIndex: combinedStIndex,
      penaltiesDrawn: penaltiesDrawn,
      penaltiesTaken: penaltiesTaken,
      netPenalties: netPenalties,
    );
  }

  /// Calculates on-ice shot differential (Player Corsi) for a skater
  static OnIceShotStats getOnIceShotStats(Player player, List<GameEvent> gameEvents, String teamId) {
    if (player.position == 'G') {
      return OnIceShotStats(
        shotsForOnIce: 0,
        shotsAgainstOnIce: 0,
        netShotsOnIce: 0,
        shotSharePercentage: 0.0,
      );
    }

    int shotsFor = 0;
    int shotsAgainst = 0;

    for (final event in gameEvents) {
      if (event.eventType == 'Shot') {
        final onIce = event.yourTeamPlayersOnIce;
        if (onIce != null && onIce.contains(player.id)) {
          if (event.team == teamId) {
            shotsFor++;
          } else {
            shotsAgainst++;
          }
        }
      }
    }

    final netShots = shotsFor - shotsAgainst;
    final totalShots = shotsFor + shotsAgainst;
    final share = totalShots > 0 ? (shotsFor / totalShots) * 100 : 0.0;

    return OnIceShotStats(
      shotsForOnIce: shotsFor,
      shotsAgainstOnIce: shotsAgainst,
      netShotsOnIce: netShots,
      shotSharePercentage: share,
    );
  }

  /// Returns list of shots faced by a specified goalie (or opponent goalie)
  static List<GameEvent> getShotsFacedByGoalie(
    Player goalie,
    List<GameEvent> gameEvents,
    String teamId, {
    List<Player>? teamGoalies,
    bool isOpponentGoalie = false,
  }) {
    if (isOpponentGoalie) {
      // Shots faced by opponent goalie are shots taken by your team
      return gameEvents.where((e) => e.eventType == 'Shot' && e.team == teamId).toList();
    }

    final isOnlyGoalie = teamGoalies != null &&
        teamGoalies.length == 1 &&
        teamGoalies.first.id == goalie.id;

    return gameEvents.where((event) =>
      event.eventType == 'Shot' &&
      event.team != teamId &&
      (event.goalieOnIceId == goalie.id ||
          (isOnlyGoalie && (event.goalieOnIceId == null || event.goalieOnIceId!.isEmpty)))
    ).toList();
  }
}
