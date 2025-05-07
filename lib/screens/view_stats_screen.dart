import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';

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
    final players = playersBox.values.where((player) => player.teamId == 'your_team').toList();

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
            DataTable(
              columns: const <DataColumn>[
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Jersey #',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Goals',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Shots on Goal',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Assists',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Points',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Penalty Minutes',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Plus/Minus',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ],
              rows: <DataRow>[
                for (var player in players)
                  DataRow(
                    cells: <DataCell>[
                      DataCell(Text('${player.jerseyNumber}')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && event.primaryPlayerId == player.id).length}')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.primaryPlayerId == player.id).length}')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && (event.assistPlayer1Id == player.id || event.assistPlayer2Id == player.id)).length}')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && event.primaryPlayerId == player.id).length + gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && (event.assistPlayer1Id == player.id || event.assistPlayer2Id == player.id)).length}')),
                      DataCell(Text('${gameEvents.where((event) => event.eventType == 'Penalty' && event.primaryPlayerId == player.id).map((event) => event.penaltyDuration).fold(0, (a, b) => a! + b!)}')),
                      DataCell(Text('${calculatePlusMinus(player, gameEvents, gameId!)}')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 32.0),
            const Text('Game Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16.0),
            DataTable(
              columns: const <DataColumn>[
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Stat',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Your Team',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Opponent',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
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
          ],
        ),
      ),
    );
  }
}

int calculatePlusMinus(Player player, List<GameEvent> gameEvents, String gameId) {
  int plus = 0;
  int minus = 0;

  // Calculate plus for when the player is on the ice when your team scores
  for (var event in gameEvents) {
    if (event.eventType == 'Shot' && event.isGoal == true && event.gameId == gameId) {
      if (event.team == 'Your Team') {
        if (event.yourTeamPlayersOnIceIds != null && event.yourTeamPlayersOnIceIds!.contains(player.id)) {
          plus++;
        }
      } else if (event.team == 'Opponent' && event.yourTeamPlayersOnIceIds != null && event.yourTeamPlayersOnIceIds!.contains(player.id)) {
        minus--; // Decrement minus instead of incrementing
      }
    }
  }

  //If the player is on the opponent's team, return 0
  // Assuming teamId is null or empty for opponent players
  if(player.teamId != null && player.teamId!.isNotEmpty){
    return plus - minus;
  } else {
    return 0;
  }
}
