import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';

// Stage-2 regression tests for the duplicate-event-rows bug (2026-10-21):
// the event upload's existence check conflated "not found" with "lookup
// failed", so a sync on flaky Wi-Fi appended events that were already in
// the sheet. _findEventRow now returns null on lookup failure and both
// sync paths abort the write in that state; the in-flight guard set is
// static so overlapping passes from different SheetsService instances
// can't check-then-append the same event. These tests pin the pure row
// search both paths rely on.
void main() {
  group('SheetsService.findRowInIdValues', () {
    final column = <List<dynamic>>[
      ['ID'], // header row
      ['evt-1'],
      ['evt-2'],
      ['evt-3'],
    ];

    test('finds the 1-based sheet row of an event', () {
      expect(SheetsService.findRowInIdValues(column, 'evt-2'), 3);
      expect(SheetsService.findRowInIdValues(column, 'evt-1'), 2);
    });

    test('returns -1 when the ID is definitively absent', () {
      expect(SheetsService.findRowInIdValues(column, 'evt-99'), -1);
      expect(SheetsService.findRowInIdValues([], 'evt-1'), -1);
    });

    test('returns the FIRST row when the ID is duplicated', () {
      final dup = <List<dynamic>>[
        ['ID'],
        ['evt-1'],
        ['evt-2'],
        ['evt-1'],
      ];
      // Updates target the first copy — the canonical row.
      expect(SheetsService.findRowInIdValues(dup, 'evt-1'), 2);
    });

    test('empty rows are skipped, not crashed on', () {
      final sparse = <List<dynamic>>[
        ['ID'],
        <dynamic>[],
        ['evt-7'],
      ];
      expect(SheetsService.findRowInIdValues(sparse, 'evt-7'), 3);
    });
  });
}
