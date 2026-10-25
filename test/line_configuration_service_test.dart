import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/services/line_configuration_service.dart';

/// The saved-line-config guard (Oct 2026): a saved setup that belongs to
/// a different team or season must never be applied over the auto-dealt
/// lines — applying it resolves every foreign player ID to an empty
/// slot. This bit a multi-team phone during the Stars U15 BB setup,
/// where the device-wide 'current_game' fallback held another team's
/// lines and blanked the whole screen.
void main() {
  group('LineConfigurationService.configBelongsToRoster', () {
    final roster = {'player_142', 'player_143', 'player_151'};

    test('a config from this roster belongs', () {
      final config = [
        ['player_142', 'player_143', null],
        [null, null, null],
      ];
      expect(
        LineConfigurationService.configBelongsToRoster(config, roster),
        isTrue,
      );
    });

    test('a config with even one roster player among foreign IDs belongs', () {
      final config = [
        ['player_88', 'player_151', 'player_90'],
      ];
      expect(
        LineConfigurationService.configBelongsToRoster(config, roster),
        isTrue,
      );
    });

    test('a fully foreign config does not belong', () {
      final config = [
        ['player_88', 'player_89', 'player_90'],
        ['player_91', 'player_92'],
      ];
      expect(
        LineConfigurationService.configBelongsToRoster(config, roster),
        isFalse,
      );
    });

    test('an all-empty config belongs (it was deliberately cleared)', () {
      final config = [
        [null, null, null],
        [null, null],
      ];
      expect(
        LineConfigurationService.configBelongsToRoster(config, roster),
        isTrue,
      );
    });

    test('an empty config belongs', () {
      expect(
        LineConfigurationService.configBelongsToRoster([], roster),
        isTrue,
      );
    });

    test('against an empty roster, any referenced player is foreign', () {
      final config = [
        ['player_142', null, null],
      ];
      expect(
        LineConfigurationService.configBelongsToRoster(config, <String>{}),
        isFalse,
      );
    });
  });
}
