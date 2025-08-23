import 'package:hive/hive.dart';

part 'data_models.g.dart';

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

  Game({
    required this.id,
    required this.date,
    required this.opponent,
    this.location,
  });
  
  Game copyWith({
    String? id,
    DateTime? date,
    String? opponent,
    String? location,
  }) {
    return Game(
      id: id ?? this.id,
      date: date ?? this.date,
      opponent: opponent ?? this.opponent,
      location: location ?? this.location,
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
