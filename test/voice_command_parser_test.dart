import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/voice_command_parser.dart';

void main() {
  Player p(int jersey) => Player(
        id: 'player_$jersey',
        jerseyNumber: jersey,
        teamId: 'waxersu13a',
        position: 'F',
      );

  final roster = [p(7), p(9), p(12), p(25), p(49), p(88), p(91)];
  late VoiceCommandParser parser;

  setUp(() {
    parser = VoiceCommandParser(roster);
  });

  group('shots', () {
    test('"shot" alone is a team shot', () {
      final result = parser.parse('Shot');
      expect(result.isSuccess, isTrue);
      expect(result.command!.kind, VoiceCommandKind.teamShot);
      expect(result.command!.describe(), 'Team shot');
    });

    test('"team shot" is a team shot', () {
      final result = parser.parse('team shot');
      expect(result.command!.kind, VoiceCommandKind.teamShot);
    });

    test('"opponent shot" is an opponent shot', () {
      final result = parser.parse('Opponent shot');
      expect(result.command!.kind, VoiceCommandKind.opponentShot);
      expect(result.command!.describe(), 'Opponent shot');
    });

    test('"shot 25" is a player shot for #25', () {
      final result = parser.parse('Shot 25');
      expect(result.command!.kind, VoiceCommandKind.playerShot);
      expect(result.command!.player!.jerseyNumber, 25);
      expect(result.command!.describe(), 'Shot — #25');
    });

    test('spoken number words work: "shot twenty five"', () {
      final result = parser.parse('shot twenty five');
      expect(result.command!.kind, VoiceCommandKind.playerShot);
      expect(result.command!.player!.jerseyNumber, 25);
    });

    test('hyphenated numbers work: "shot twenty-five"', () {
      final result = parser.parse('shot twenty-five');
      expect(result.command!.player!.jerseyNumber, 25);
    });

    test('a shot for a number not on the roster is rejected', () {
      final result = parser.parse('shot 99');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('#99'));
    });

    test('two numbers for a shot are rejected', () {
      final result = parser.parse('shot 25 and 88');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('more than one number'));
    });
  });

  group('goals', () {
    test('"goal 25" is an unassisted goal', () {
      final result = parser.parse('Goal 25');
      expect(result.command!.kind, VoiceCommandKind.goal);
      expect(result.command!.player!.jerseyNumber, 25);
      expect(result.command!.assist1, isNull);
      expect(result.command!.situation, isNull);
      expect(result.command!.describe(), 'Goal — #25');
    });

    test('goal with two assists', () {
      final result = parser.parse('Goal 25, assists 88 and 49');
      final cmd = result.command!;
      expect(cmd.player!.jerseyNumber, 25);
      expect(cmd.assist1!.jerseyNumber, 88);
      expect(cmd.assist2!.jerseyNumber, 49);
      expect(cmd.describe(), 'Goal — #25 · Assists #88, #49');
    });

    test('goal with one assist, spoken numbers', () {
      final result = parser.parse('goal nine assist eighty eight');
      final cmd = result.command!;
      expect(cmd.player!.jerseyNumber, 9);
      expect(cmd.assist1!.jerseyNumber, 88);
      expect(cmd.assist2, isNull);
    });

    test('spoken situation is captured', () {
      final result = parser.parse('goal 25 power play');
      expect(result.command!.situation, GoalSituation.powerPlay);
      expect(result.command!.describe(), contains('Power play'));
    });

    test('short handed situation is captured', () {
      final result = parser.parse('goal 25 short handed');
      expect(result.command!.situation, GoalSituation.shortHanded);
    });

    test('goal without a scorer is rejected', () {
      final result = parser.parse('goal');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('who scored'));
    });

    test('scorer cannot assist on their own goal', () {
      final result = parser.parse('goal 25 assist 25');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('own goal'));
    });

    test('an assist not on the roster is rejected', () {
      final result = parser.parse('goal 25 assists 88 and 99');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('#99'));
    });

    test('more than two assists are rejected', () {
      final result = parser.parse('goal 25 assists 88 49 and 91');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('at most two'));
    });
  });

  group('penalties', () {
    test('full penalty command with digit numbers', () {
      final result = parser.parse('Penalty 12, tripping, 2 minutes');
      final cmd = result.command!;
      expect(cmd.kind, VoiceCommandKind.penalty);
      expect(cmd.player!.jerseyNumber, 12);
      expect(cmd.penaltyType, 'Tripping');
      expect(cmd.penaltyMinutes, 2);
      expect(cmd.describe(), 'Penalty — #12 · Tripping · 2 min');
    });

    test('full penalty command with spoken numbers', () {
      final result = parser.parse('penalty twelve hooking two minutes');
      final cmd = result.command!;
      expect(cmd.player!.jerseyNumber, 12);
      expect(cmd.penaltyType, 'Hooking');
      expect(cmd.penaltyMinutes, 2);
    });

    test('multi-word penalty types canonicalize', () {
      expect(parser.parse('penalty 7 high sticking 2 minutes')
          .command!
          .penaltyType, 'High-sticking');
      expect(parser.parse('penalty 7 cross checking 2 minutes')
          .command!
          .penaltyType, 'Cross-checking');
      expect(parser.parse('penalty 7 too many men 2 minutes')
          .command!
          .penaltyType, 'Too Many Men');
      expect(parser.parse('penalty 7 unsportsmanlike 2 minutes')
          .command!
          .penaltyType, 'Unsportsmanlike Conduct');
    });

    test('penalty without a duration is rejected', () {
      final result = parser.parse('penalty 12 tripping');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('penalty length'));
    });

    test('penalty without a type is rejected', () {
      final result = parser.parse('penalty 12 2 minutes');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('penalty type'));
    });

    test('penalty without a player is rejected', () {
      final result = parser.parse('penalty tripping 2 minutes');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('who took the penalty'));
    });
  });

  group('undo and rejections', () {
    test('"undo" parses', () {
      expect(parser.parse('undo').command!.kind, VoiceCommandKind.undo);
      expect(parser.parse('Undo last').command!.kind, VoiceCommandKind.undo);
    });

    test('opponent goal is rejected with guidance', () {
      final result = parser.parse('opponent goal');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('Log Shot screen'));
    });

    test('gibberish is rejected, never guessed', () {
      final result = parser.parse('banana pancakes friday');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('Didn\'t understand'));
    });

    test('empty input is rejected', () {
      final result = parser.parse('   ');
      expect(result.isSuccess, isFalse);
      expect(result.rejectionReason, contains('Nothing was heard'));
    });
  });
}
