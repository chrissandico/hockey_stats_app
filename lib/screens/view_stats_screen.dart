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
              child: Theme(
                data: Theme.of(context).copyWith(
                  dataTableTheme: DataTableThemeData(
                    headingRowColor: MaterialStateProperty.all(Colors.black),
                    headingTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                child: DataTable2(
                  border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                  columnSpacing: 15.0,
                  headingRowHeight: 50,
                  dataRowHeight: 45,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('POS')),
                    DataColumn(label: Text('G'), numeric: true),
                    DataColumn(label: Text('A'), numeric: true),
                    DataColumn(label: Text('+/-'), numeric: true),
                    DataColumn(label: Text('PIM'), numeric: true),
                    DataColumn(label: Text('SOG'), numeric: true),
                  ],
                  rows: players.asMap().entries.map((entry) {
                    final index = entry.key;
                    final player = entry.value;
                    return DataRow(
                      color: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.hovered)) {
                            return Colors.blue.withOpacity(0.1);
                          }
                          return index.isEven ? Colors.grey.shade100 : null;
                        },
                      ),
                      cells: [
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              player.jerseyNumber.toString(),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              player.position ?? 'N/A',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && event.primaryPlayerId == player.id).length.toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && (event.assistPlayer1Id == player.id || event.assistPlayer2Id == player.id)).length.toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              calculatePlusMinus(player, gameEvents, gameId!).toString(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: calculatePlusMinus(player, gameEvents, gameId!) > 0 
                                  ? Colors.green 
                                  : calculatePlusMinus(player, gameEvents, gameId!) < 0 
                                    ? Colors.red 
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              gameEvents.where((event) => event.eventType == 'Penalty' && event.primaryPlayerId == player.id).map((event) => event.penaltyDuration).fold(0, (a, b) => a! + b!).toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              gameEvents.where((event) => event.eventType == 'Shot' && event.primaryPlayerId == player.id).length.toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
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
