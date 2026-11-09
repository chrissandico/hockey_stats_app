import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/pdf_service.dart';

/// PDF report changes (Oct 2026):
/// 1. "Top Defensemen" ranks by Corsi (net shots on ice), not plus/minus.
/// 2. The player listing is ordered by position group, then jersey number.
void main() {
  const teamId = 'starsu15bb';

  Player p(String id, int jersey, String pos) =>
      Player(id: id, jerseyNumber: jersey, teamId: teamId, position: pos);

  GameEvent shot(String id, String team, List<String> onIce,
          {bool goal = false}) =>
      GameEvent(
        id: id,
        gameId: 'g1',
        timestamp: DateTime(2026, 10, 25),
        period: 1,
        eventType: 'Shot',
        team: team,
        primaryPlayerId: team == teamId ? 'shooter' : 'opp1',
        isGoal: goal,
        yourTeamPlayersOnIce: onIce,
      );

  group('PdfService.comparePlayersForListing', () {
    test('forwards first, then defensemen, then goalies; jersey breaks ties',
        () {
      final players = [
        p('g1', 1, 'G'),
        p('d49', 49, 'D'),
        p('f21', 21, 'F'),
        p('d7', 7, 'D'),
        p('f9', 9, 'F'),
      ];
      players.sort(PdfService.comparePlayersForListing);
      expect(
        players.map((e) => e.id).toList(),
        ['f9', 'f21', 'd7', 'd49', 'g1'],
      );
    });

    test('detailed positions group with their families (LW/C forwards, LD/RD defense)',
        () {
      final players = [
        p('rd', 5, 'RD'),
        p('lw', 88, 'LW'),
        p('c', 91, 'C'),
        p('ld', 3, 'LD'),
      ];
      players.sort(PdfService.comparePlayersForListing);
      expect(
        players.map((e) => e.id).toList(),
        ['lw', 'c', 'ld', 'rd'],
      );
    });
  });

  group('PdfService.getTopDefensemen — Corsi, not plus/minus', () {
    test(
        'the Corsi leader wins even when another defenseman owns the better plus/minus',
        () {
      final dCorsi = p('dA', 49, 'D'); // 6 shots for, 1 against, no goals: Corsi +5, +/- 0
      final dPlus = p('dB', 66, 'D'); // on ice for 2 team goals: Corsi +2, +/- +2
      final fwd = p('fC', 21, 'F'); // huge Corsi but a forward: excluded
      final events = <GameEvent>[
        for (var i = 0; i < 6; i++) shot('a$i', teamId, ['dA']),
        shot('a6', 'opponent', ['dA']),
        shot('b0', teamId, ['dB'], goal: true),
        shot('b1', teamId, ['dB'], goal: true),
        for (var i = 0; i < 9; i++) shot('c$i', teamId, ['fC']),
      ];

      final top = PdfService().getTopDefensemen([dCorsi, dPlus, fwd], events, teamId);

      expect(top.map((s) => (s['player'] as Player).id).toList(), ['dA']);
      expect(top.single['corsi'], 5);
    });

    test('defensemen tied on Corsi are all returned', () {
      final d1 = p('d1', 49, 'D');
      final d2 = p('d2', 66, 'D');
      final events = [
        shot('x1', teamId, ['d1', 'd2']),
        shot('x2', teamId, ['d1', 'd2']),
      ];

      final top = PdfService().getTopDefensemen([d1, d2], events, teamId);

      expect(top.length, 2);
      expect(top.every((s) => s['corsi'] == 2), isTrue);
    });

    test('no defensemen on the roster returns an empty list', () {
      final top = PdfService().getTopDefensemen([p('f1', 9, 'F')], [], teamId);
      expect(top, isEmpty);
    });
  });
}
