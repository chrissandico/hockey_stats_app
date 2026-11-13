import '../models/data_models.dart';

/// The PP/PK mode toggle on Track Stats doesn't just flip a mode — it logs
/// a synthetic Penalty event (no player, type 'Unspecified', 2 minutes)
/// that carries the power-play / penalty-kill opportunity count:
///
/// - a **power play** marker is filed as an OPPONENT penalty (their
///   penalty gave us the power play);
/// - a **penalty kill** marker is filed as OUR penalty.
///
/// These helpers are the single definition of what a marker is. They exist
/// because markers must never be treated as called penalties: the regular
/// penalty edit screen hard-codes our team and requires a player, so
/// "editing" a power-play marker there would silently flip it into a
/// penalty-kill marker and corrupt the counts.
bool isSituationMarker(GameEvent event) =>
    event.eventType == 'Penalty' &&
    event.primaryPlayerId.isEmpty &&
    (event.penaltyType == null || event.penaltyType == 'Unspecified');

/// A marker is a power-play marker when the underlying penalty belongs to
/// the opponent.
bool isPowerPlayMarker(GameEvent event) =>
    isSituationMarker(event) && event.team == 'opponent';

/// Plain-language name for the marker, e.g. for list rows.
String situationMarkerLabel(GameEvent event) =>
    isPowerPlayMarker(event) ? 'Power Play marker' : 'Penalty Kill marker';

/// Flips a marker between power play and penalty kill by switching which
/// team the underlying penalty belongs to (opponent <-> [teamId]) — the
/// fix for tapping the wrong PP/PK button. The event keeps its id, so the
/// synced Sheet row updates in place; the caller persists the change and
/// re-queues the event for sync.
void convertSituationMarker(GameEvent event, {required String teamId}) {
  event.team = event.team == 'opponent' ? teamId : 'opponent';
  event.version = event.version + 1;
  event.isSynced = false;
}
