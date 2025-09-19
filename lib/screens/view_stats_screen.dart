import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hockey_stats_app/widgets/share_dialog.dart';
import 'package:hockey_stats_app/services/stats_service.dart';

class ViewStatsScreen extends StatefulWidget {
  const ViewStatsScreen({super.key, this.gameId, required this.teamId});

  final String? gameId;
  final String teamId;

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
    players = playersBox.values.where((player) => player.teamId == widget.teamId).toList();
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
            icon: const Icon(Icons.share),
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
                  builder: (context) => ShareDialog(
                    players: players,
                    gameEvents: gameEvents,
                    game: game,
                    teamId: widget.teamId,
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
                        headingRowColor: WidgetStateProperty.all(Colors.black),
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
                      ],
                      rows: players.asMap().entries.map((entry) {
                        final index = entry.key;
                        final player = entry.value;
                        final plusMinus = StatsService.calculatePlusMinus(player, gameEvents, widget.teamId);
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.hovered)) {
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
                                  StatsService.calculateGoals(player, gameEvents).toString(),
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
                                  StatsService.calculateAssists(player, gameEvents).toString(),
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
                                  StatsService.calculatePenaltyMinutes(player, gameEvents).toString(),
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
