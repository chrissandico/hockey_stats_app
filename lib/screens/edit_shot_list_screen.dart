import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:hockey_stats_app/services/centralized_data_service.dart';
import 'package:hockey_stats_app/services/memory_cache_service.dart';
import 'package:hockey_stats_app/services/background_sync_service.dart';
import 'package:hockey_stats_app/services/situation_marker.dart';
import 'package:intl/intl.dart'; // For date formatting

class EditShotListScreen extends StatefulWidget {
  final String gameId;
  final String teamId;

  const EditShotListScreen({super.key, required this.gameId, required this.teamId});

  @override
  _EditShotListScreenState createState() => _EditShotListScreenState();
}

class _EditShotListScreenState extends State<EditShotListScreen> {
  late Box<GameEvent> gameEventsBox;
  late Box<Player> playersBox;
  List<GameEvent> gameEvents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    playersBox = Hive.box<Player>('players');
    _loadGameEvents();
  }

  void _loadGameEvents() {
    setState(() {
      isLoading = true;
    });

    // Get all shot and penalty events for this game
    gameEvents = gameEventsBox.values
        .where((event) => 
          event.gameId == widget.gameId && 
          (event.eventType == 'Shot' || event.eventType == 'Penalty'))
        .toList();

    // Sort by timestamp, most recent first
    gameEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      isLoading = false;
    });
  }

  // Helper method to get player display text
  String _getPlayerDisplayText(String playerId, bool isYourTeam) {
    if (!isYourTeam) {
      return 'Opponent';
    }
    
    // Handle empty or null player IDs for your team
    if (playerId.isEmpty) {
      return 'Team Event';
    }
    
    try {
      final player = playersBox.values.firstWhere((p) => p.id == playerId);
      return '#${player.jerseyNumber}';
    } catch (e) {
      return 'Unknown Player';
    }
  }

  // Format timestamp to a readable time
  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('h:mm a').format(timestamp);
  }

  // Get period display text
  String _getPeriodText(int period) {
    return period == 4 ? 'OT' : 'P$period';
  }

  // ---------------------------------------------------------------------------
  // PP/PK situation markers: the synthetic penalty events the mode toggle
  // creates. They are not called penalties, so they get their own actions —
  // convert PP <-> PK, move period, or delete (below) — and are never sent
  // to the penalty edit screen, whose save hard-codes our team and requires
  // a player (it would silently flip a PP marker into a PK marker).
  // ---------------------------------------------------------------------------

  Future<void> _showMarkerActions(GameEvent event) async {
    final isPP = isPowerPlayMarker(event);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                situationMarkerLabel(event),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Created by the PP/PK toggle — not a called penalty. '
                'It carries the ${isPP ? 'power play' : 'penalty kill'} opportunity count.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(isPP
                  ? 'Change to Penalty Kill marker'
                  : 'Change to Power Play marker'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _convertMarker(event);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  const Text('Period: '),
                  const SizedBox(width: 8),
                  ...[1, 2, 3, 4].map(
                    (period) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(period == 4 ? 'OT' : '$period'),
                        selected: event.period == period,
                        onSelected: (_) {
                          Navigator.of(sheetContext).pop();
                          if (period != event.period) {
                            _setMarkerPeriod(event, period);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertMarker(GameEvent event) async {
    convertSituationMarker(event, teamId: widget.teamId);
    await _saveMarkerChange(
        event, 'Changed to a ${situationMarkerLabel(event).toLowerCase()}');
  }

  Future<void> _setMarkerPeriod(GameEvent event, int period) async {
    event.period = period;
    event.version = event.version + 1;
    event.isSynced = false;
    await _saveMarkerChange(event, 'Marker moved to ${_getPeriodText(period)}');
  }

  /// Persists a marker change the way a penalty edit is saved: box put,
  /// cache refresh, and the sync queue, so the Sheet row updates in place.
  Future<void> _saveMarkerChange(GameEvent event, String message) async {
    await gameEventsBox.put(event.id, event);
    MemoryCacheService().cacheEvent(event);
    CentralizedDataService().invalidateEvent(widget.gameId);
    CentralizedDataService().clearCache();
    BackgroundSyncService().queueEventForSync(event);
    _loadGameEvents();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Delete event with confirmation
  Future<void> _deleteEvent(GameEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          // Synthetic penalties (blank player + 'Unspecified') are created by the
          // PP/PK mode toggle and carry the PP/PK opportunity count with them.
          isSituationMarker(event)
              ? 'This entry marks a power play / penalty kill (it was created by the PP/PK mode toggle, not a called penalty). Deleting it changes the PP/PK opportunity count. Delete it?'
              : 'Are you sure you want to delete this ${event.eventType.toLowerCase()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting event...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      try {
        final sheetsService = SheetsService();
        bool deletedFromSheets = false;
        
        // First try to delete from Google Sheets if the event was synced
        if (event.isSynced) {
          deletedFromSheets = await sheetsService.deleteEventFromSheet(event.id);
          
          if (!deletedFromSheets) {
            // If Google Sheets deletion failed, ask user if they want to continue with local deletion
            final continueWithLocal = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                    const SizedBox(width: 8),
                    const Text('Offline Mode Detected'),
                  ],
                ),
                content: const Text(
                  'Your device appears to be offline. All changes are safely stored and will automatically sync when your connection is restored.'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );
            
            if (continueWithLocal != true) {
              return; // User cancelled, don't delete locally
            }

            // Queue pending deletion for background sync when online
            await sheetsService.queuePendingDeletion(event.id);
          }
        } else {
          // Event was not synced to Google Sheets, so we only need to delete locally
          deletedFromSheets = true; // Consider it successful since there's nothing to delete from sheets
        }
        
        // Delete from local database
        await event.delete();
        
        // Invalidate caches to trigger immediate score/stats recalculations
        CentralizedDataService().invalidateEvent(widget.gameId);
        CentralizedDataService().clearCache();
        MemoryCacheService().removeEvent(event.id);

        // Refresh the list
        _loadGameEvents();
        
        // Show appropriate success message
        if (mounted) {
          String message;
          if (event.isSynced && deletedFromSheets) {
            message = '${event.eventType} deleted successfully from both local database and Google Sheets';
          } else if (event.isSynced && !deletedFromSheets) {
            message = '${event.eventType} deleted locally (queued to sync deletion when online)';
          } else {
            message = '${event.eventType} deleted successfully';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: (event.isSynced && !deletedFromSheets) ? Colors.orange : Colors.green,
            ),
          );
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting ${event.eventType.toLowerCase()}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Game Events'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : gameEvents.isEmpty
              ? const Center(child: Text('No events logged for this game yet.'))
              : ListView.builder(
                  itemCount: gameEvents.length,
                  itemBuilder: (context, index) {
                    final event = gameEvents[index];
                    final isShot = event.eventType == 'Shot';
                    final isPenalty = event.eventType == 'Penalty';
                    final isGoal = event.isGoal ?? false;
                    final isYourTeam = event.team == widget.teamId;
                    final isMarker = isSituationMarker(event);
                    final isPowerPlay = isPowerPlayMarker(event);
                    
                    // Determine event display text
                    String eventTypeText = '';
                    String playerText = _getPlayerDisplayText(event.primaryPlayerId, isYourTeam);
                    String detailText = '';
                    
                    if (isShot) {
                      eventTypeText = isGoal ? 'Goal' : 'Shot';
                      if (isGoal) {
                        // Add goal situation information
                        String situationText = '';
                        if (event.goalSituation != null) {
                          switch (event.goalSituation!) {
                            case GoalSituation.powerPlay:
                              situationText = 'Power Play';
                              break;
                            case GoalSituation.shortHanded:
                              situationText = 'Penalty Kill';
                              break;
                            case GoalSituation.evenStrength:
                              situationText = 'Even Strength';
                              break;
                          }
                        } else {
                          situationText = 'Even Strength'; // Default for older goals without situation data
                        }
                        
                        // Build detail text with situation and assist
                        List<String> details = [situationText];
                        if (isYourTeam && event.assistPlayer1Id != null && event.assistPlayer1Id!.isNotEmpty) {
                          details.add('Assist: ${_getPlayerDisplayText(event.assistPlayer1Id!, true)}');
                        }
                        detailText = ' (${details.join(', ')})';
                      }
                    } else if (isPenalty) {
                      eventTypeText = 'Penalty';
                      if (event.penaltyType != null && event.penaltyType!.isNotEmpty) {
                        detailText = ' - ${event.penaltyType}';
                        if (event.penaltyDuration != null && event.penaltyDuration! > 0) {
                          detailText += ' (${event.penaltyDuration} min)';
                        }
                      }
                    }

                    // Choose icon and color based on event type and team
                    IconData iconData;
                    Color backgroundColor;
                    
                    if (isShot) {
                      iconData = isGoal ? Icons.sports_score : Icons.sports_hockey;
                      backgroundColor = isGoal ? Colors.green : Colors.blue;
                    } else {
                      iconData = Icons.warning;
                      backgroundColor = Colors.orange;
                    }
                    
                    // Add team color distinction - make opponent events more visually distinct
                    if (!isYourTeam) {
                      backgroundColor = Colors.red.withOpacity(0.7);
                    }

                    // Situation markers get their own icon and colour —
                    // they are not called penalties.
                    if (isMarker) {
                      iconData = isPowerPlay ? Icons.bolt : Icons.shield;
                      backgroundColor =
                          isPowerPlay ? Colors.orange.shade800 : Colors.red.shade700;
                    }

                    final onIceIds = event.yourTeamPlayersOnIce ?? [];
                    final titleText = isMarker
                        ? situationMarkerLabel(event)
                        : '$eventTypeText by $playerText$detailText';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: backgroundColor,
                                child: Icon(
                                  iconData,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                titleText,
                                style: TextStyle(
                                  fontWeight: (isGoal || isPenalty) ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                '${_getPeriodText(event.period)} - ${_formatTimestamp(event.timestamp)}${isYourTeam ? '' : ' (Opponent)'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isMarker)
                                    // Markers never go to the penalty edit
                                    // screen — they get marker actions.
                                    IconButton(
                                      icon: const Icon(Icons.tune),
                                      tooltip: 'Change PP/PK marker',
                                      onPressed: () => _showMarkerActions(event),
                                    )
                                  else
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: isShot ? 'Edit Shot' : 'Edit Penalty',
                                    onPressed: () {
                                      // Navigate to appropriate edit screen
                                      if (isShot) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LogShotScreen(
                                              gameId: widget.gameId,
                                              period: event.period,
                                              teamId: widget.teamId,
                                              eventIdToEdit: event.id,
                                            ),
                                          ),
                                        ).then((_) {
                                          _loadGameEvents();
                                        });
                                      } else if (isPenalty) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LogPenaltyScreen(
                                              gameId: widget.gameId,
                                              period: event.period,
                                              teamId: widget.teamId,
                                              eventIdToEdit: event.id,
                                            ),
                                          ),
                                        ).then((_) {
                                          _loadGameEvents();
                                        });
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Delete Event',
                                    color: Colors.red,
                                    onPressed: () => _deleteEvent(event),
                                  ),
                                ],
                              ),
                            ),
                            if (isShot && onIceIds.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 72.0, right: 16.0, bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('On Ice: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: onIceIds.map((pId) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getPlayerDisplayText(pId, true),
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
