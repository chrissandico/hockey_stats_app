import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';

// Regression tests for the offline-game deletion bug (2026-10-19):
// a game created with no connection was only stored locally, had no sync
// state, and the full sync's per-team delete-replace of games deleted it
// before it ever uploaded. Games now carry isSynced, are uploaded by
// syncPendingGames, and are protected from the merge while unsynced.
void main() {
  group('Game sync state', () {
    test('a newly created game defaults to unsynced', () {
      final game = Game(
        id: 'g1',
        date: DateTime(2026, 10, 9),
        opponent: 'Orillia Terriers',
      );
      expect(game.isSynced, isFalse);
    });

    test('copyWith preserves and can set isSynced', () {
      final game = Game(
        id: 'g1',
        date: DateTime(2026, 10, 9),
        opponent: 'Orillia Terriers',
        isSynced: true,
      );
      expect(game.copyWith(opponent: 'Newmarket Renegades').isSynced, isTrue);
      expect(game.copyWith(isSynced: false).isSynced, isFalse);
    });

    test('legacy records without field 7 migrate as unsynced', () {
      // Game.migrate handles records written before isSynced existed:
      // they must come back unsynced (uploads are upserts, so a re-upload
      // is safe) rather than cloud-owned.
      final migrated = Game.migrate(<int, dynamic>{
        0: 'g-legacy',
        1: DateTime(2026, 10, 9),
        2: 'Orillia Terriers',
        3: 'West Orillia Sports Complex',
        4: 'jagsu13a',
        5: 1,
        6: 'R',
      });
      expect(migrated.isSynced, isFalse);
    });
  });

  group('Game adapter round-trip', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_game_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(GameAdapter());
      }
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('isSynced survives a box write/read', () async {
      final box = await Hive.openBox<Game>('games');
      await box.put(
        'g-synced',
        Game(
          id: 'g-synced',
          date: DateTime(2026, 10, 9),
          opponent: 'Orillia Terriers',
          teamId: 'jagsu13a',
          isSynced: true,
        ),
      );
      await box.put(
        'g-local',
        Game(
          id: 'g-local',
          date: DateTime(2026, 10, 17),
          opponent: 'Orangeville Flyers',
          teamId: 'jagsu13a',
        ),
      );

      expect(box.get('g-synced')!.isSynced, isTrue);
      expect(box.get('g-local')!.isSynced, isFalse);
    });
  });

  group('computeProtectedGameIds', () {
    Game game(String id, {bool synced = true}) => Game(
          id: id,
          date: DateTime(2026, 10, 9),
          opponent: 'Opp',
          isSynced: synced,
        );

    GameEvent event(String id, String gameId, {bool synced = true}) =>
        GameEvent(
          id: id,
          gameId: gameId,
          timestamp: DateTime(2026, 10, 9, 20, 30),
          period: 1,
          eventType: 'Shot',
          team: 'opponent',
          primaryPlayerId: 'opp1',
          isSynced: synced,
        );

    test('an unsynced game is protected', () {
      final ids = SheetsService.computeProtectedGameIds(
        [game('g1', synced: false)],
        const [],
      );
      expect(ids, {'g1'});
    });

    test('a synced game with only synced events is not protected', () {
      final ids = SheetsService.computeProtectedGameIds(
        [game('g1')],
        [event('e1', 'g1')],
      );
      expect(ids, isEmpty);
    });

    test('a synced game carrying an unsynced event is protected', () {
      // The event merge preserves the unsynced event; its game must be
      // preserved too or the event is orphaned.
      final ids = SheetsService.computeProtectedGameIds(
        [game('g1')],
        [event('e1', 'g1', synced: false)],
      );
      expect(ids, {'g1'});
    });

    test('protection is per game, not global', () {
      final ids = SheetsService.computeProtectedGameIds(
        [game('g1'), game('g2', synced: false)],
        [event('e1', 'g1')],
      );
      expect(ids, {'g2'});
    });
  });
}
