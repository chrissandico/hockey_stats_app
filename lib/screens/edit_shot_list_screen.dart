import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:intl/intl.dart'; // For date formatting

class EditShotListScreen extends StatefulWidget {
  final String gameId;

  const EditShotListScreen({super.key, required this.gameId});

  @override
  _EditShotListScreenState createState() => _EditShotListScreenState();
}

class _EditShotListScreenState extends State<EditShotListScreen> {
  late Box<GameEvent> gameEventsBox;
  late Box<Player> playersBox;
  List<GameEvent> shotEvents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    playersBox = Hive.box<Player>('players');
    _loadShotEvents();
  }

  void _loadShotEvents() {
    setState(() {
      isLoading = true;
    });

    // Get all shot events for this game
    shotEvents = gameEventsBox.values
        .where((event) => event.gameId == widget.gameId && event.eventType == 'Shot')
        .toList();

    // Sort by timestamp, most recent first
    shotEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      isLoading = false;
    });
  }

  // Helper method to get player jersey number from ID
  String _getPlayerJerseyNumber(String playerId) {
    try {
      final player = playersBox.values.firstWhere((p) => p.id == playerId);
      return '#${player.jerseyNumber}';
    } catch (e) {
      return 'Unknown';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Logged Shots'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : shotEvents.isEmpty
              ? const Center(child: Text('No shots logged for this game yet.'))
              : ListView.builder(
                  itemCount: shotEvents.length,
                  itemBuilder: (context, index) {
                    final event = shotEvents[index];
                    final isGoal = event.isGoal ?? false;
                    final isYourTeam = event.team == 'Your Team';
                    
                    // Determine shooter display text
                    String shooterText = isYourTeam 
                        ? _getPlayerJerseyNumber(event.primaryPlayerId)
                        : 'Opponent';
                    
                    // Determine assist display text if applicable
                    String assistText = '';
                    if (isGoal && isYourTeam && event.assistPlayer1Id != null) {
                      assistText = ' (Assist: ${_getPlayerJerseyNumber(event.assistPlayer1Id!)})';
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isGoal ? Colors.green : Colors.blue,
                          child: Icon(
                            isGoal ? Icons.sports_score : Icons.sports_hockey,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          '${isGoal ? "Goal" : "Shot"} by $shooterText$assistText',
                          style: TextStyle(
                            fontWeight: isGoal ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${_getPeriodText(event.period)} - ${_formatTimestamp(event.timestamp)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit Shot',
                          onPressed: () {
                            // Navigate to LogShotScreen in edit mode
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LogShotScreen(
                                  gameId: widget.gameId,
                                  period: event.period,
                                  eventIdToEdit: event.id,
                                ),
                              ),
                            ).then((_) {
                              // Refresh the list when returning from edit screen
                              _loadShotEvents();
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
