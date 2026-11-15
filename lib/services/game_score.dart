import '../models/data_models.dart';

/// The score of a single game, derived from its logged events.
///
/// Uses the same goal rule as CentralizedDataService.calculateCurrentScore:
/// a goal is a Shot event with isGoal == true; our goals carry
/// team == teamId and opponent goals carry team == 'opponent'.
class GameScore {
  final int goalsFor;
  final int goalsAgainst;

  const GameScore(this.goalsFor, this.goalsAgainst);

  bool get isWin => goalsFor > goalsAgainst;
  bool get isLoss => goalsFor < goalsAgainst;
  bool get isTie => goalsFor == goalsAgainst;

  /// 'W', 'L' or 'T'.
  String get resultLetter => isWin ? 'W' : (isLoss ? 'L' : 'T');

  /// Chip text, e.g. 'W 4–2'.
  String get label => '$resultLetter $goalsFor\u2013$goalsAgainst';
}

/// Scores for every game that has at least one logged event, keyed by
/// gameId, computed in a single pass over [allEvents].
///
/// A game with NO logged events is absent from the result (callers see
/// null): an unplayed game must not be presented as a 0–0 tie. A game
/// whose logged events include no goals scores a real 0–0.
Map<String, GameScore> gameScoresByGameId(
  Iterable<GameEvent> allEvents,
  String teamId,
) {
  final eventsByGame = <String, List<GameEvent>>{};
  for (final event in allEvents) {
    eventsByGame.putIfAbsent(event.gameId, () => []).add(event);
  }
  final scores = <String, GameScore>{};
  eventsByGame.forEach((gameId, events) {
    final goalsFor = events
        .where((e) =>
            e.eventType == 'Shot' && e.isGoal == true && e.team == teamId)
        .length;
    final goalsAgainst = events
        .where((e) =>
            e.eventType == 'Shot' && e.isGoal == true && e.team == 'opponent')
        .length;
    scores[gameId] = GameScore(goalsFor, goalsAgainst);
  });
  return scores;
}
