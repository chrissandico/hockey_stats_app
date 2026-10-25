import 'package:flutter_test/flutter_test.dart';
import 'package:hockey_stats_app/services/service_account_auth.dart';

/// The token-staleness policy behind the October 2026 "sync buttons
/// fail until the app is restarted" bug: requests used to send the
/// cached token forever, because the refresh check only looked at
/// whether a token existed, never at whether it had expired.
void main() {
  final now = DateTime(2026, 10, 25, 12, 0, 0);

  group('ServiceAccountAuth.shouldRefreshToken', () {
    test('no token at all refreshes', () {
      expect(
        ServiceAccountAuth.shouldRefreshToken(
          hasToken: false,
          expiry: now.add(const Duration(hours: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('token without a recorded expiry refreshes', () {
      expect(
        ServiceAccountAuth.shouldRefreshToken(
          hasToken: true,
          expiry: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('fresh token with an hour left does not refresh', () {
      expect(
        ServiceAccountAuth.shouldRefreshToken(
          hasToken: true,
          expiry: now.add(const Duration(hours: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('token inside the 5-minute skew window refreshes', () {
      expect(
        ServiceAccountAuth.shouldRefreshToken(
          hasToken: true,
          expiry: now.add(const Duration(minutes: 4)),
          now: now,
        ),
        isTrue,
      );
    });

    test('token at the skew boundary refreshes', () {
      expect(
        ServiceAccountAuth.shouldRefreshToken(
          hasToken: true,
          expiry: now.add(ServiceAccountAuth.tokenRefreshSkew),
          now: now,
        ),
        isTrue,
      );
    });

    test('already-expired token refreshes', () {
      expect(
        ServiceAccountAuth.shouldRefreshToken(
          hasToken: true,
          expiry: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
