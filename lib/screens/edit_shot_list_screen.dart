import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
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

  // Delete event with confirmation
  Future<void> _deleteEvent(GameEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete this ${event.eventType.toLowerCase()}?'),
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
          }
        } else {
          // Event was not synced to Google Sheets, so we only need to delete locally
          deletedFromSheets = true; // Consider it successful since there's nothing to delete from sheets
        }
        
        // Delete from local database
        await event.delete();
        
        // Refresh the list
        _loadGameEvents();
        
        // Show appropriate success message
        if (mounted) {
          String message;
          if (event.isSynced && deletedFromSheets) {
            message = '${event.eventType} deleted successfully from both local database and Google Sheets';
          } else if (event.isSynced && !deletedFromSheets) {
            message = '${event.eventType} deleted locally (Google Sheets deletion failed)';
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

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: backgroundColor,
                          child: Icon(
                            iconData,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          '$eventTypeText by $playerText$detailText',
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
                    );
                  },
                ),
    );
  }
}
