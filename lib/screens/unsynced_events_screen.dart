import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:hockey_stats_app/services/background_sync_service.dart';
import 'package:intl/intl.dart';

class UnsyncedEventsScreen extends StatefulWidget {
  final String? gameId;
  
  const UnsyncedEventsScreen({super.key, this.gameId});

  @override
  State<UnsyncedEventsScreen> createState() => _UnsyncedEventsScreenState();
}

class _UnsyncedEventsScreenState extends State<UnsyncedEventsScreen> {
  late Box<GameEvent> gameEventsBox;
  late Box<GameRoster> gameRosterBox;
  late Box<Player> playersBox;
  late Box<Game> gamesBox;
  
  List<GameEvent> unsyncedEvents = [];
  List<GameRoster> unsyncedRoster = [];
  bool isLoading = true;
  bool isSyncing = false;
  String selectedFilter = 'All';
  
  final SheetsService _sheetsService = SheetsService();
  final BackgroundSyncService _backgroundSyncService = BackgroundSyncService();

  @override
  void initState() {
    super.initState();
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    gameRosterBox = Hive.box<GameRoster>('gameRoster');
    playersBox = Hive.box<Player>('players');
    gamesBox = Hive.box<Game>('games');
    _loadUnsyncedData();
  }

  void _loadUnsyncedData() {
    setState(() {
      isLoading = true;
    });

    // Get user preferences to filter events
    final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
    final prefs = prefsBox.get('user_prefs') ?? SyncPreferences();

    // Get all unsynced events
    var allUnsyncedEvents = gameEventsBox.values
        .where((event) => !event.isSynced)
        .toList();

    // Get all unsynced roster entries
    var allUnsyncedRoster = gameRosterBox.values
        .where((roster) => !roster.isSynced)
        .toList();

    // Filter by game ID if specified
    if (widget.gameId != null) {
      allUnsyncedEvents = allUnsyncedEvents
          .where((event) => event.gameId == widget.gameId)
          .toList();
      allUnsyncedRoster = allUnsyncedRoster
          .where((roster) => roster.gameId == widget.gameId)
          .toList();
    }

    // Filter events based on user preferences
    final filteredEvents = allUnsyncedEvents.where((event) => prefs.shouldSyncEvent(event)).toList();
    
    // Filter roster based on user preferences
    final filteredRoster = prefs.shouldSyncAttendance() ? allUnsyncedRoster : <GameRoster>[];

    unsyncedEvents = filteredEvents;
    unsyncedRoster = filteredRoster;

    // Sort events by timestamp, most recent first
    unsyncedEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    print('UnsyncedEventsScreen: Loaded ${allUnsyncedEvents.length} total unsynced events, showing ${filteredEvents.length} after preference filtering');
    print('UnsyncedEventsScreen: Loaded ${allUnsyncedRoster.length} total unsynced roster entries, showing ${filteredRoster.length} after preference filtering');

    setState(() {
      isLoading = false;
    });
  }

  List<GameEvent> get filteredEvents {
    if (selectedFilter == 'All') {
      return unsyncedEvents;
    }
    return unsyncedEvents.where((event) => event.eventType == selectedFilter).toList();
  }

  String _getPlayerDisplayText(String playerId, String teamId) {
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

  String _getGameDisplayText(String gameId) {
    try {
      final game = gamesBox.values.firstWhere((g) => g.id == gameId);
      final dateStr = DateFormat('MMM d').format(game.date);
      return '$dateStr vs ${game.opponent}';
    } catch (e) {
      return 'Game $gameId';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('MMM d, h:mm a').format(timestamp);
  }

  String _getPeriodText(int period) {
    return period == 4 ? 'OT' : 'P$period';
  }

  Future<void> _syncAllEvents() async {
    setState(() {
      isSyncing = true;
    });

    try {
      // Get sync preferences for display
      final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
      final prefs = prefsBox.get('user_prefs') ?? SyncPreferences();
      final syncSummary = prefs.getSyncSummary();

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Syncing Events'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Syncing ${unsyncedEvents.length + unsyncedRoster.length} items for this game...'),
              const SizedBox(height: 8),
              Text(
                'Sync types: $syncSummary',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Use game-specific sync methods that respect preferences
      final eventResults = await _sheetsService.syncPendingEventsForGame(widget.gameId);
      final rosterResults = await _sheetsService.syncPendingAttendanceForGame(widget.gameId);

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      final totalSuccess = (eventResults['success'] ?? 0) + (rosterResults['success'] ?? 0);
      final totalFailed = (eventResults['failed'] ?? 0) + (rosterResults['failed'] ?? 0);

      // Show results
      String message;
      Color backgroundColor = Colors.green;
      
      if (totalFailed == 0 && totalSuccess > 0) {
        message = 'Successfully synced all $totalSuccess eligible items for this game!';
      } else if (totalSuccess > 0) {
        message = 'Synced $totalSuccess items, $totalFailed failed for this game';
        backgroundColor = Colors.orange;
      } else if (totalFailed > 0) {
        message = 'Sync failed for $totalFailed items';
        backgroundColor = Colors.red;
      } else {
        message = 'No eligible items to sync for this game based on your preferences';
        backgroundColor = Colors.blue;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Reload data
      _loadUnsyncedData();

    } catch (e) {
      // Close progress dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSyncing = false;
        });
      }
    }
  }

  Future<void> _syncSingleEvent(GameEvent event) async {
    try {
      final success = await _sheetsService.syncGameEvent(event);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${event.eventType} synced successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadUnsyncedData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync ${event.eventType}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEventCard(GameEvent event) {
    final isShot = event.eventType == 'Shot';
    final isPenalty = event.eventType == 'Penalty';
    final isGoal = event.isGoal ?? false;
    
    // Determine event display text
    String eventTypeText = '';
    String playerText = _getPlayerDisplayText(event.primaryPlayerId, event.team);
    String detailText = '';
    
    if (isShot) {
      eventTypeText = isGoal ? 'Goal' : 'Shot';
      if (isGoal && event.goalSituation != null) {
        switch (event.goalSituation!) {
          case GoalSituation.powerPlay:
            detailText = ' (Power Play)';
            break;
          case GoalSituation.shortHanded:
            detailText = ' (Penalty Kill)';
            break;
          case GoalSituation.evenStrength:
            detailText = ' (Even Strength)';
            break;
        }
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

    // Choose icon and color
    IconData iconData;
    Color backgroundColor;
    
    if (isShot) {
      iconData = isGoal ? Icons.sports_score : Icons.sports_hockey;
      backgroundColor = isGoal ? Colors.green : Colors.blue;
    } else {
      iconData = Icons.warning;
      backgroundColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: backgroundColor,
          child: Icon(iconData, color: Colors.white, size: 20),
        ),
        title: Text(
          '$eventTypeText by $playerText$detailText',
          style: TextStyle(
            fontWeight: (isGoal || isPenalty) ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGameDisplayText(event.gameId)} - ${_getPeriodText(event.period)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              _formatTimestamp(event.timestamp),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.cloud_upload, size: 20),
          tooltip: 'Sync this event',
          onPressed: () => _syncSingleEvent(event),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildRosterCard(GameRoster roster) {
    String playerText = _getPlayerDisplayText(roster.playerId, 'team');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roster.status == 'Present' ? Colors.green : Colors.grey,
          child: Icon(
            roster.status == 'Present' ? Icons.person : Icons.person_off,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          'Attendance: $playerText',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGameDisplayText(roster.gameId)} - ${roster.status}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.cloud_upload, size: 20),
          tooltip: 'Sync attendance',
          onPressed: () async {
            try {
              final success = await _sheetsService.syncGameRoster(roster);
              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Attendance synced successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                _loadUnsyncedData();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to sync attendance'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sync error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUnsyncedCount = unsyncedEvents.length + unsyncedRoster.length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unsynced Events'),
        actions: [
          if (totalUnsyncedCount > 0)
            IconButton(
              icon: const Icon(Icons.cloud_sync),
              tooltip: 'Sync All',
              onPressed: isSyncing ? null : _syncAllEvents,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : totalUnsyncedCount == 0
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_done, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'All events are synced!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your data is up to date with Google Sheets.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary card
                    Card(
                      margin: const EdgeInsets.all(16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pending Sync',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${unsyncedEvents.length}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const Text('Events'),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${unsyncedRoster.length}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const Text('Attendance'),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '$totalUnsyncedCount',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const Text('Total'),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: Builder(
                                builder: (context) {
                                  // Get sync preferences for button text
                                  final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
                                  final prefs = prefsBox.get('user_prefs') ?? SyncPreferences();
                                  final syncSummary = prefs.getSyncSummary();
                                  
                                  String buttonText;
                                  if (isSyncing) {
                                    buttonText = 'Syncing...';
                                  } else if (widget.gameId != null) {
                                    buttonText = 'Sync $syncSummary for This Game';
                                  } else {
                                    buttonText = 'Sync $syncSummary';
                                  }
                                  
                                  return ElevatedButton.icon(
                                    onPressed: isSyncing ? null : _syncAllEvents,
                                    icon: isSyncing 
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.cloud_sync),
                                    label: Text(buttonText),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Filter tabs
                    if (unsyncedEvents.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'All',
                              'Shot',
                              'Penalty',
                            ].map((filter) {
                              final isSelected = selectedFilter == filter;
                              final count = filter == 'All' 
                                  ? unsyncedEvents.length
                                  : unsyncedEvents.where((e) => e.eventType == filter).length;
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text('$filter ($count)'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedFilter = filter;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Events list
                    Expanded(
                      child: ListView(
                        children: [
                          // Events
                          if (filteredEvents.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                'Events',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            ...filteredEvents.map(_buildEventCard),
                          ],
                          
                          // Roster entries (only show when "All" filter is selected)
                          if (selectedFilter == 'All' && unsyncedRoster.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                'Attendance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            ...unsyncedRoster.map(_buildRosterCard),
                          ],
                          
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
