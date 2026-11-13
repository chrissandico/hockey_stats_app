import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/situation_marker.dart';

void main() {
  GameEvent penalty({
    required String team,
    String playerId = '',
    String? penaltyType = 'Unspecified',
    int? duration = 2,
  }) {
    return GameEvent(
      id: 'evt_1',
      gameId: 'game_1',
      timestamp: DateTime(2026, 11, 13, 19, 30),
      period: 2,
      eventType: 'Penalty',
      team: team,
      primaryPlayerId: playerId,
      penaltyType: penaltyType,
      penaltyDuration: duration,
      isSynced: true,
    );
  }

  group('isSituationMarker', () {
    test('a power-play marker (opponent penalty, no player, Unspecified)', () {
      expect(isSituationMarker(penalty(team: 'opponent')), isTrue);
    });

    test('a penalty-kill marker (our penalty, no player, Unspecified)', () {
      expect(isSituationMarker(penalty(team: 'waxersu13a')), isTrue);
    });

    test('a null penalty type with no player is also a marker', () {
      expect(
          isSituationMarker(penalty(team: 'opponent', penaltyType: null)),
          isTrue);
    });

    test('a called penalty (has a player) is not a marker', () {
      expect(
        isSituationMarker(penalty(
            team: 'waxersu13a', playerId: 'player_25', penaltyType: 'Tripping')),
        isFalse,
      );
    });

    test('no player but a real called type is not a marker', () {
      expect(
        isSituationMarker(penalty(team: 'waxersu13a', penaltyType: 'Hooking')),
        isFalse,
      );
    });

    test('a shot is never a marker', () {
      final shot = GameEvent(
        id: 'evt_2',
        gameId: 'game_1',
        timestamp: DateTime(2026, 11, 13),
        period: 1,
        eventType: 'Shot',
        team: 'waxersu13a',
        primaryPlayerId: '',
        isSynced: true,
      );
      expect(isSituationMarker(shot), isFalse);
    });
  });

  group('power play vs penalty kill', () {
    test('opponent marker is a power-play marker with the PP label', () {
      final marker = penalty(team: 'opponent');
      expect(isPowerPlayMarker(marker), isTrue);
      expect(situationMarkerLabel(marker), 'Power Play marker');
    });

    test('our marker is a penalty-kill marker with the PK label', () {
      final marker = penalty(team: 'waxersu13a');
      expect(isPowerPlayMarker(marker), isFalse);
      expect(situationMarkerLabel(marker), 'Penalty Kill marker');
    });
  });

  group('convertSituationMarker', () {
    test('PP marker converts to PK: team flips to ours, version bumps, '
        'marked unsynced, id unchanged', () {
      final marker = penalty(team: 'opponent');
      final originalVersion = marker.version;
      convertSituationMarker(marker, teamId: 'waxersu13a');
      expect(marker.team, 'waxersu13a');
      expect(isPowerPlayMarker(marker), isFalse);
      expect(marker.version, originalVersion + 1);
      expect(marker.isSynced, isFalse);
      expect(marker.id, 'evt_1');
    });

    test('PK marker converts to PP: team flips to opponent', () {
      final marker = penalty(team: 'waxersu13a');
      convertSituationMarker(marker, teamId: 'waxersu13a');
      expect(marker.team, 'opponent');
      expect(isPowerPlayMarker(marker), isTrue);
    });

    test('converting twice restores the original team', () {
      final marker = penalty(team: 'opponent');
      convertSituationMarker(marker, teamId: 'waxersu13a');
      convertSituationMarker(marker, teamId: 'waxersu13a');
      expect(marker.team, 'opponent');
    });
  });
}
