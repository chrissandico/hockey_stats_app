import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:data_table_2/data_table_2.dart'; // Import DataTable2

class ViewStatsScreen extends StatelessWidget {
  const ViewStatsScreen({super.key, this.gameId});

  final String? gameId;

  @override
  Widget build(BuildContext context) {
    // Access Hive boxes
    final gameEventsBox = Hive.box<GameEvent>('gameEvents');
    final playersBox = Hive.box<Player>('players');

    // Get all game events
    final gameEvents = gameEventsBox.values.where((event) => event.gameId == gameId).toList();

    // Get all players, filter out opponent players
    List<Player> players = playersBox.values.where((player) => player.teamId == 'your_team').toList();

    // Sort players by jersey number in ascending order
    players.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Stats'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            const Text('Individual Player Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16.0),
            // Replace SingleChildScrollView and DataTable with DataTable2
            SizedBox( // DataTable2 often needs a defined height or to be in an Expanded widget
              height: (players.length + 1) * 56.0 + 20, // Estimate height: (num_rows + header_row) * row_height + padding
              child: DataTable2(
                columnSpacing: 12,
                horizontalMargin: 12,
                minWidth: 600, // Adjust as needed for your content
                fixedLeftColumns: 1, // Freeze the first column
                columns: const <DataColumn>[
                  DataColumn(
                    label: Text(
                      'Jersey #',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataColumn( // New column for Position
                    label: Text(
                      'POS',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'G',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'A',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '+/-',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'PIM',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'SOG',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                rows: <DataRow>[
                  for (var player in players)
                    DataRow(
                      cells: <DataCell>[
                        DataCell(Text('${player.jerseyNumber}')),
                        DataCell(Text(player.position?.isNotEmpty == true ? player.position! : 'N/A')), // Display position or N/A
                        DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && event.primaryPlayerId == player.id).length}')),
                        DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && (event.assistPlayer1Id == player.id || event.assistPlayer2Id == player.id)).length}')),
                        DataCell(Text('${calculatePlusMinus(player, gameEvents, gameId!)}')),
                        DataCell(Text('${gameEvents.where((event) => event.eventType == 'Penalty' && event.primaryPlayerId == player.id).map((event) => event.penaltyDuration).fold(0, (a, b) => a! + b!)}')),
                        DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.primaryPlayerId == player.id).length}')),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8.0), // Further reduced height
            const Text('Game Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16.0),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(
                    label: Text(
                      'Stat',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Your Team',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Opponent',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                rows: <DataRow>[
                  DataRow(
                    cells: <DataCell>[
                      const DataCell(Text('Game Score')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && event.team == 'Your Team').length}')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && event.team == 'Opponent').length}')),
                    ],
                  ),
                  DataRow(
                    cells: <DataCell>[
                      const DataCell(Text('Shots on Goal')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.team == 'Your Team').length}')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.team == 'Opponent').length}')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int calculatePlusMinus(Player player, List<GameEvent> gameEvents, String gameId) {
  int plusMinus = 0;

  // Calculate plus/minus for when the player is on the ice when a goal is scored
  for (var event in gameEvents) {
    if (event.eventType == 'Shot' && event.isGoal == true && event.gameId == gameId) {
      // Only consider events where we have players on ice data
      if (event.yourTeamPlayersOnIceIds != null && event.yourTeamPlayersOnIceIds!.isNotEmpty) {
        // Check if the player was on ice
        if (event.yourTeamPlayersOnIceIds!.contains(player.id)) {
          // If your team scored, add +1
          if (event.team == 'Your Team') {
            plusMinus++;
          } 
          // If opponent scored, subtract 1
          else if (event.team == 'Opponent') {
            plusMinus--;
          }
        }
      }
    }
  }

  return plusMinus;
}
