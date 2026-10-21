import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/custom_adapters.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression tests for the gameType-overwrite bug (2026-10-21):
// the pre-fix CustomGameAdapter never wrote gameType (field 6) or
// isSynced (field 7), so every locally stored game read back as
// type 'R' / unsynced, and the game push machinery rewrote the
// sheet's rows as 'R'. Two defences are pinned here:
//  1. the PRODUCTION adapter round-trips both fields (the older
//     sync tests registered the generated adapter by mistake — an
//     adapter production doesn't run — which is how this shipped);
//  2. the heal gate: no game pushes until one full download merge
//     has rewritten the local store from the sheet.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('heal_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(CustomGameAdapter());
    await Hive.openBox<Game>('games');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box<Game>('games').clear();
    SharedPreferences.setMockInitialValues({});
  });

  Game game(String id, {String type = 'R', bool synced = true}) => Game(
        id: id,
        date: DateTime(2026, 9, 26),
        opponent: 'Test Opponent',
        location: 'Arena',
        teamId: 'jagsu13a',
        gameType: type,
        isSynced: synced,
      );

  group('CustomGameAdapter (the adapter production registers)', () {
    test('round-trips gameType P and isSynced through the box', () async {
      final box = Hive.box<Game>('games');
      await box.put('g1', game('g1', type: 'P', synced: true));
      final back = box.get('g1');
      expect(back, isNotNull);
      expect(back!.gameType, 'P');
      expect(back.isSynced, isTrue);
    });

    test('round-trips gameType T and unsynced', () async {
      final box = Hive.box<Game>('games');
      await box.put('g2', game('g2', type: 'T', synced: false));
      final back = box.get('g2');
      expect(back!.gameType, 'T');
      expect(back.isSynced, isFalse);
    });
  });

  group('heal gate', () {
    test('flag defaults to not healed, and marking sets it', () async {
      expect(await SheetsService.isGameStoreHealed(), isFalse);
      await SheetsService.markGameStoreHealed();
      expect(await SheetsService.isGameStoreHealed(), isTrue);
    });

    test('syncPendingGames holds unsynced games while unhealed', () async {
      final box = Hive.box<Game>('games');
      await box.put('g3', game('g3', type: 'T', synced: false));

      final result = await SheetsService().syncPendingGames();

      expect(result['total'], 1);
      expect(result['success'], 0);
      expect(result['failed'], 0);
      // Still local, still flagged unsynced — nothing was pushed.
      expect(box.get('g3')!.isSynced, isFalse);
    });

    test('syncGame refuses to push while unhealed', () async {
      final pushed = await SheetsService().syncGame(game('g4', synced: false));
      expect(pushed, isFalse);
    });
  });
}
