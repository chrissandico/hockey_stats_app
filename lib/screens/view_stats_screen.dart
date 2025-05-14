import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hockey_stats_app/widgets/email_dialog.dart';

class ViewStatsScreen extends StatefulWidget {
  const ViewStatsScreen({super.key, this.gameId});

  final String? gameId;

  @override
  State<ViewStatsScreen> createState() => _ViewStatsScreenState();
}

class _ViewStatsScreenState extends State<ViewStatsScreen> {
  late List<Player> players;

  @override
  void initState() {
    super.initState();
    // Get all players, filter out opponent players
    final playersBox = Hive.box<Player>('players');
    players = playersBox.values.where((player) => player.teamId == 'your_team').toList();
    // Sort players by jersey number in ascending order
    players.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.email),
            onPressed: () async {
              final gamesBox = Hive.box<Game>('games');
              final game = gamesBox.get(widget.gameId);
              if (game == null) return;

              final gameEventsBox = Hive.box<GameEvent>('gameEvents');
              final gameEvents = gameEventsBox.values
                  .where((event) => event.gameId == widget.gameId)
                  .toList();

              if (mounted) {
                await showDialog(
                  context: context,
                  builder: (context) => EmailDialog(
                    players: players,
                    gameEvents: gameEvents,
                    game: game,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            const Text('Individual Player Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16.0),
            ValueListenableBuilder(
              valueListenable: Hive.box<GameEvent>('gameEvents').listenable(),
              builder: (context, Box<GameEvent> gameEventsBox, _) {
                // Get all game events for this game
                final gameEvents = gameEventsBox.values.where((event) => event.gameId == widget.gameId).toList();

                return SizedBox(
                  height: (players.length + 1) * 56.0 + 20,
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
                        final plusMinus = calculatePlusMinus(player, gameEvents);
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
                                  plusMinus.toString(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: plusMinus > 0 
                                      ? Colors.green 
                                      : plusMinus < 0 
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
                                  gameEvents
                                    .where((event) => event.eventType == 'Penalty' && event.primaryPlayerId == player.id)
                                    .map((event) => event.penaltyDuration ?? 0)
                                    .fold(0, (a, b) => a + b)
                                    .toString(),
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
                                  gameEvents
                                    .where((event) => 
                                      event.eventType == 'Shot' && 
                                      event.primaryPlayerId == player.id
                                    )
                                    .length
                                    .toString(),
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

int calculatePlusMinus(Player player, List<GameEvent> gameEvents) {
  int plusMinus = 0;

  // Calculate plus/minus for when the player is on the ice when a goal is scored
  for (var event in gameEvents) {
    if (event.eventType == 'Shot' && event.isGoal == true) {
      bool playerWasOnIce = false;

      if (event.team == 'your_team') {
        // For your team's goals, check players on ice or involvement in the play
        if (event.yourTeamPlayersOnIce != null && event.yourTeamPlayersOnIce!.isNotEmpty) {
          playerWasOnIce = event.yourTeamPlayersOnIce!.contains(player.id);
        } else {
          playerWasOnIce = event.primaryPlayerId == player.id || 
                          event.assistPlayer1Id == player.id || 
                          event.assistPlayer2Id == player.id;
        }
        if (playerWasOnIce) {
          plusMinus++;
        }
      } else if (event.team == 'opponent') {
        // For opponent goals, all your team players on ice get a minus
        if (event.yourTeamPlayersOnIce != null && event.yourTeamPlayersOnIce!.isNotEmpty) {
          playerWasOnIce = event.yourTeamPlayersOnIce!.contains(player.id);
          if (playerWasOnIce) {
            plusMinus--;
          }
        }
        // If no players on ice data for opponent goals, we can't determine plus/minus
      }
    }
  }

  return plusMinus;
}
