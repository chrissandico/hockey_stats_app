// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 0;

  @override
  Player read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Player(
      id: fields[0] as String,
      jerseyNumber: fields[1] as int,
      teamId: fields[2] as String?,
      position: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.jerseyNumber)
      ..writeByte(2)
      ..write(obj.teamId)
      ..writeByte(3)
      ..write(obj.position);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GameAdapter extends TypeAdapter<Game> {
  @override
  final int typeId = 1;

  @override
  Game read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Game(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      opponent: fields[2] as String,
      location: fields[3] as String?,
      teamId: fields[4] as String,
      version: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Game obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.opponent)
      ..writeByte(3)
      ..write(obj.location)
      ..writeByte(4)
      ..write(obj.teamId)
      ..writeByte(5)
      ..write(obj.version);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GameEventAdapter extends TypeAdapter<GameEvent> {
  @override
  final int typeId = 2;

  @override
  GameEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameEvent(
      id: fields[0] as String,
      gameId: fields[1] as String,
      timestamp: fields[2] as DateTime,
      period: fields[3] as int,
      eventType: fields[4] as String,
      team: fields[5] as String,
      primaryPlayerId: fields[6] as String,
      assistPlayer1Id: fields[7] as String?,
      assistPlayer2Id: fields[8] as String?,
      isGoal: fields[9] as bool?,
      penaltyType: fields[10] as String?,
      penaltyDuration: fields[11] as int?,
      yourTeamPlayersOnIce: (fields[12] as List?)?.cast<String>(),
      isSynced: fields[13] as bool,
      version: fields[14] as int?,
      goalSituation: fields[15] as GoalSituation?,
    );
  }

  @override
  void write(BinaryWriter writer, GameEvent obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.gameId)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.period)
      ..writeByte(4)
      ..write(obj.eventType)
      ..writeByte(5)
      ..write(obj.team)
      ..writeByte(6)
      ..write(obj.primaryPlayerId)
      ..writeByte(7)
      ..write(obj.assistPlayer1Id)
      ..writeByte(8)
      ..write(obj.assistPlayer2Id)
      ..writeByte(9)
      ..write(obj.isGoal)
      ..writeByte(10)
      ..write(obj.penaltyType)
      ..writeByte(11)
      ..write(obj.penaltyDuration)
      ..writeByte(12)
      ..write(obj.yourTeamPlayersOnIce)
      ..writeByte(13)
      ..write(obj.isSynced)
      ..writeByte(14)
      ..write(obj.version)
      ..writeByte(15)
      ..write(obj.goalSituation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EmailSettingsAdapter extends TypeAdapter<EmailSettings> {
  @override
  final int typeId = 3;

  @override
  EmailSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmailSettings(
      defaultEmailAddresses: (fields[0] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, EmailSettings obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.defaultEmailAddresses);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GameRosterAdapter extends TypeAdapter<GameRoster> {
  @override
  final int typeId = 4;

  @override
  GameRoster read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameRoster(
      id: fields[0] as String,
      gameId: fields[1] as String,
      playerId: fields[2] as String,
      status: fields[3] as String,
      timestamp: fields[4] as DateTime,
      isSynced: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GameRoster obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.gameId)
      ..writeByte(2)
      ..write(obj.playerId)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameRosterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalSituationAdapter extends TypeAdapter<GoalSituation> {
  @override
  final int typeId = 5;

  @override
  GoalSituation read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GoalSituation.evenStrength;
      case 1:
        return GoalSituation.powerPlay;
      case 2:
        return GoalSituation.shortHanded;
      default:
        return GoalSituation.evenStrength;
    }
  }

  @override
  void write(BinaryWriter writer, GoalSituation obj) {
    switch (obj) {
      case GoalSituation.evenStrength:
        writer.writeByte(0);
        break;
      case GoalSituation.powerPlay:
        writer.writeByte(1);
        break;
      case GoalSituation.shortHanded:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalSituationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
