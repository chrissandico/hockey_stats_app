import 'package:hive/hive.dart';

part 'data_models.g.dart';

@HiveType(typeId: 5)
enum GoalSituation {
  @HiveField(0)
  evenStrength,
  
  @HiveField(1)
  powerPlay,
  
  @HiveField(2)
  shortHanded,
}

@HiveType(typeId: 0)
class Player extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int jerseyNumber;

  @HiveField(2)
  String? teamId;

  @HiveField(3)
  String? position;

  Player({
    required this.id,
    required this.jerseyNumber,
    this.teamId,
    this.position,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@HiveType(typeId: 1)
class Game extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String opponent;

  @HiveField(3)
  String? location;
  
  @HiveField(4)
  String teamId;
  
  @HiveField(5)
  int version;
  
  @HiveField(6)
  String gameType;

  Game({
    required this.id,
    required this.date,
    required this.opponent,
    this.location,
    this.teamId = 'your_team',
    this.version = 1,
    this.gameType = 'R', // Default to Regular Season
  });
  
  /// Factory constructor for migrating from older versions
  factory Game.migrate(Map<int, dynamic> fields) {
    // Handle missing teamId field (added in version 1)
    final String teamId = fields[4] as String? ?? 'your_team';
    // Handle missing gameType field (added in version 2)
    final String gameType = fields[6] as String? ?? 'R';
    
    return Game(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      opponent: fields[2] as String,
      location: fields[3] as String?,
      teamId: teamId,
      version: 1, // Set to current version
      gameType: gameType,
    );
  }
  
  Game copyWith({
    String? id,
    DateTime? date,
    String? opponent,
    String? location,
    String? teamId,
    int? version,
    String? gameType,
  }) {
    return Game(
      id: id ?? this.id,
      date: date ?? this.date,
      opponent: opponent ?? this.opponent,
      location: location ?? this.location,
      teamId: teamId ?? this.teamId,
      version: version ?? this.version,
      gameType: gameType ?? this.gameType,
    );
  }
}

@HiveType(typeId: 2)
class GameEvent extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String gameId;

  @HiveField(2)
  DateTime timestamp;

  @HiveField(3)
  int period;

  @HiveField(4)
  String eventType;

  @HiveField(5)
  String team;

  @HiveField(6)
  String primaryPlayerId;

  @HiveField(7)
  String? assistPlayer1Id;

  @HiveField(8)
  String? assistPlayer2Id;

  @HiveField(9)
  bool? isGoal;

  @HiveField(10)
  String? penaltyType;

  @HiveField(11)
  int? penaltyDuration;

  @HiveField(12)
  List<String>? yourTeamPlayersOnIce;

  @HiveField(13)
  bool isSynced;
  
  @HiveField(14)
  int version = 1;

  @HiveField(15)
  GoalSituation? goalSituation;

  @HiveField(16)
  String? goalieOnIceId;

  GameEvent({
    required this.id,
    required this.gameId,
    required this.timestamp,
    required this.period,
    required this.eventType,
    required this.team,
    required this.primaryPlayerId,
    this.assistPlayer1Id,
    this.assistPlayer2Id,
    bool? isGoal,
    this.penaltyType,
    this.penaltyDuration,
    this.yourTeamPlayersOnIce,
    this.isSynced = false,
    int? version,
    this.goalSituation,
    this.goalieOnIceId,
  }) : version = version ?? 1 {
    this.isGoal = isGoal ?? false;
  }
}

@HiveType(typeId: 3)
class EmailSettings extends HiveObject {
  @HiveField(0)
  List<String> defaultEmailAddresses;

  EmailSettings({
    required this.defaultEmailAddresses,
  });
}

@HiveType(typeId: 4)
class GameRoster extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String gameId;

  @HiveField(2)
  String playerId;

  @HiveField(3)
  String status; // 'Present' or 'Absent'

  @HiveField(4)
  DateTime timestamp;

  @HiveField(5)
  bool isSynced;

  GameRoster({
    required this.id,
    required this.gameId,
    required this.playerId,
    required this.status,
    required this.timestamp,
    this.isSynced = false,
  });
}

class PlayerSeasonStats {
  final String playerId; 
  String playerName;
  int playerJerseyNumber;
  String? playerPosition;
  int goals;
  int assists;
  int get points => goals + assists;
  int shots;
  int penaltyMinutes;
  int plusMinus;

  PlayerSeasonStats({
    required this.playerId,
    this.playerName = '',
    this.playerJerseyNumber = 0,
    this.playerPosition,
    this.goals = 0,
    this.assists = 0,
    this.shots = 0,
    this.penaltyMinutes = 0,
    this.plusMinus = 0,
  });

  void updatePlayerDetails(Player player) {
    playerJerseyNumber = player.jerseyNumber;
    playerPosition = player.position;
  }
}

class GoalieSeasonStats {
  final String playerId;
  String playerName;
  int playerJerseyNumber;
  int shotsAgainst;
  int goalsAgainst;
  int get saves => shotsAgainst - goalsAgainst;
  double get savePercentage => shotsAgainst > 0 ? saves / shotsAgainst : 0.0;
  int gamesPlayed;
  Set<String> _gamesPlayedSet = {}; // Track unique games

  GoalieSeasonStats({
    required this.playerId,
    this.playerName = '',
    this.playerJerseyNumber = 0,
    this.shotsAgainst = 0,
    this.goalsAgainst = 0,
    this.gamesPlayed = 0,
  });

  void updatePlayerDetails(Player player) {
    playerJerseyNumber = player.jerseyNumber;
    playerName = '#${player.jerseyNumber}';
  }

  void addGamePlayed(String gameId) {
    if (_gamesPlayedSet.add(gameId)) {
      gamesPlayed = _gamesPlayedSet.length;
    }
  }
}
