import 'package:hockey_stats_app/models/data_models.dart';

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
        
        // RULE 1: Power Play Goal - No +/- awarded to anyone
        if (event.goalSituation == GoalSituation.powerPlay) {
          continue; // Skip this goal entirely - no plus/minus changes
        }
        
        // RULE 2 & 3: Even Strength and Short-Handed Goals - Award +/-
        if (event.goalSituation == GoalSituation.evenStrength || 
            event.goalSituation == GoalSituation.shortHanded) {
          
          bool playerWasOnIce = _wasPlayerOnIce(player, event, teamId);
          
          if (event.team == teamId && playerWasOnIce) {
            // Player gets +1 for team goal (scoring team)
            plusMinus++;
          } else if (event.team == 'opponent' && playerWasOnIce) {
            // Player gets -1 for opponent goal (defending team)
            plusMinus--;
          }
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
    } else if (event.team == 'opponent') {
      // For opponent goals, check if player was on ice for your team
      if (event.yourTeamPlayersOnIce != null && event.yourTeamPlayersOnIce!.isNotEmpty) {
        return event.yourTeamPlayersOnIce!.contains(player.id);
      }
      // If no players on ice data for opponent goals, we can't determine plus/minus
      return false;
    }
    
    return false;
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
  static int calculateShotsAgainst(Player goalie, List<GameEvent> gameEvents, String teamId) {
    if (goalie.position != 'G') return 0;
    
    return gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.team != teamId && // Opponent shots
      event.goalieOnIceId == goalie.id
    ).length;
  }

  /// Calculate goals against for a goalie
  static int calculateGoalsAgainst(Player goalie, List<GameEvent> gameEvents, String teamId) {
    if (goalie.position != 'G') return 0;
    
    return gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true &&
      event.team != teamId && // Opponent goals
      event.goalieOnIceId == goalie.id
    ).length;
  }

  /// Calculate saves for a goalie
  static int calculateSaves(Player goalie, List<GameEvent> gameEvents, String teamId) {
    if (goalie.position != 'G') return 0;
    
    final shotsAgainst = calculateShotsAgainst(goalie, gameEvents, teamId);
    final goalsAgainst = calculateGoalsAgainst(goalie, gameEvents, teamId);
    return shotsAgainst - goalsAgainst;
  }

  /// Calculate save percentage for a goalie
  static double calculateSavePercentage(Player goalie, List<GameEvent> gameEvents, String teamId) {
    if (goalie.position != 'G') return 0.0;
    
    final shotsAgainst = calculateShotsAgainst(goalie, gameEvents, teamId);
    if (shotsAgainst == 0) return 0.0;
    
    final saves = calculateSaves(goalie, gameEvents, teamId);
    return saves / shotsAgainst;
  }

  /// Calculate games played for a goalie
  static int calculateGamesPlayed(Player goalie, List<GameEvent> gameEvents) {
    if (goalie.position != 'G') return 0;
    
    // Count unique games where the goalie was on ice
    final uniqueGames = gameEvents
        .where((event) => event.goalieOnIceId == goalie.id)
        .map((event) => event.gameId)
        .toSet();
    
    return uniqueGames.length;
  }

  /// Get complete goalie statistics
  static GoalieSeasonStats getGoalieStats(Player goalie, List<GameEvent> gameEvents, String teamId) {
    if (goalie.position != 'G') {
      return GoalieSeasonStats(playerId: goalie.id);
    }
    
    final stats = GoalieSeasonStats(
      playerId: goalie.id,
      playerName: '#${goalie.jerseyNumber}',
      playerJerseyNumber: goalie.jerseyNumber,
      shotsAgainst: calculateShotsAgainst(goalie, gameEvents, teamId),
      goalsAgainst: calculateGoalsAgainst(goalie, gameEvents, teamId),
      gamesPlayed: calculateGamesPlayed(goalie, gameEvents),
    );
    
    // Add games played tracking
    final uniqueGames = gameEvents
        .where((event) => event.goalieOnIceId == goalie.id)
        .map((event) => event.gameId)
        .toSet();
    
    for (final gameId in uniqueGames) {
      stats.addGamePlayed(gameId);
    }
    
    return stats;
  }
}
