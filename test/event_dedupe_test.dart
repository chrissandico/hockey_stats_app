import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';

// Regression tests for the duplicate-event-rows bug (2026-10-21):
// a retried upload appended a second sheet row for the same event ID,
// and fetch-based consumers (the PDF report above all) counted both
// copies — a 0-4 game produced a 0-5 PDF. fetchEvents now collapses
// duplicates by ID, keeping the last row (the newest version).
void main() {
  GameEvent ev(String id, {bool isGoal = false, int period = 1}) => GameEvent(
        id: id,
        gameId: '188',
        timestamp: DateTime(2026, 10, 19, 13, 29, 30),
        period: period,
        eventType: 'Shot',
        team: 'opponent',
        primaryPlayerId: '',
        isGoal: isGoal,
      );

  group('SheetsService.dedupeEventsById', () {
    test('identical duplicate rows collapse to one event', () {
      final out = SheetsService.dedupeEventsById([ev('a'), ev('b'), ev('a')]);
      expect(out.map((e) => e.id), ['b', 'a']);
    });

    test('the last copy wins when versions differ (edited event)', () {
      final out = SheetsService.dedupeEventsById([
        ev('a', isGoal: false),
        ev('a', isGoal: true),
      ]);
      expect(out, hasLength(1));
      expect(out.single.isGoal, isTrue);
    });

    test('a duplicated goal is counted once', () {
      final out = SheetsService.dedupeEventsById([
        ev('g', isGoal: true),
        ev('s'),
        ev('g', isGoal: true),
      ]);
      expect(out.where((e) => e.isGoal == true), hasLength(1));
      expect(out, hasLength(2));
    });

    test('no duplicates: list passes through unchanged', () {
      final input = [ev('a'), ev('b', period: 2), ev('c', period: 3)];
      final out = SheetsService.dedupeEventsById(input);
      expect(out.map((e) => e.id), ['a', 'b', 'c']);
      expect(out.map((e) => e.period), [1, 2, 3]);
    });

    test('empty list stays empty', () {
      expect(SheetsService.dedupeEventsById([]), isEmpty);
    });
  });
}
