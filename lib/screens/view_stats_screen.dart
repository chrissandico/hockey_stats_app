import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hockey_stats_app/widgets/share_dialog.dart';
import 'package:hockey_stats_app/widgets/goalie_stats_widget.dart';
import 'package:hockey_stats_app/widgets/score_summary_widget.dart';
import 'package:hockey_stats_app/services/stats_service.dart';
import 'package:hockey_stats_app/services/centralized_data_service.dart';

class ViewStatsScreen extends StatefulWidget {
  const ViewStatsScreen({super.key, this.gameId, required this.teamId});

  final String? gameId;
  final String teamId;

  @override
  State<ViewStatsScreen> createState() => _ViewStatsScreenState();
}

class _ViewStatsScreenState extends State<ViewStatsScreen> {
  late List<Player> players;
  late List<Player> goalies;
  final CentralizedDataService _centralizedDataService = CentralizedDataService();
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    // Get all players, filter out opponent players
    final playersBox = Hive.box<Player>('players');
    final allPlayers = playersBox.values.where((player) => player.teamId == widget.teamId).toList();
    
    // Separate goalies from skaters
    goalies = allPlayers.where((player) => player.position == 'G').toList();
    players = allPlayers.where((player) => player.position != 'G').toList();
    
    // Sort both lists by jersey number in ascending order
    players.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    goalies.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Load fresh stats from Google Sheets
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    if (!mounted) return;
    setState(() { _isLoadingStats = true; });
    
    try {
      // Force refresh from Google Sheets to get the latest data
      print('Refreshing stats from Google Sheets...');
      if (widget.gameId != null) {
        await _centralizedDataService.getCurrentGameEvents(widget.gameId!, forceRefresh: true);
      } else {
        await _centralizedDataService.getAllCurrentGameEvents(forceRefresh: true);
      }
      
      if (mounted) {
        setState(() { _isLoadingStats = false; });
      }
    } catch (e) {
      print('Error refreshing stats: $e');
      if (mounted) {
        setState(() { _isLoadingStats = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh from Google Sheets',
            onPressed: _isLoadingStats ? null : _refreshStats,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final gamesBox = Hive.box<Game>('games');
              final game = gamesBox.get(widget.gameId);
              if (game == null) return;

              // Get fresh data from centralized service
              final gameEvents = widget.gameId != null 
                  ? await _centralizedDataService.getCurrentGameEvents(widget.gameId!)
                  : await _centralizedDataService.getAllCurrentGameEvents();

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
            // Add Score Summary Widget
            FutureBuilder<List<GameEvent>>(
              future: widget.gameId != null 
                  ? _centralizedDataService.getCurrentGameEvents(widget.gameId!)
                  : _centralizedDataService.getAllCurrentGameEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isLoadingStats) {
                  return const ScoreSummaryWidget(
                    gameEvents: [],
                    teamId: '',
                    isLoading: true,
                  );
                }
                
                final gameEvents = snapshot.data ?? [];

                return ScoreSummaryWidget(
                  gameEvents: gameEvents,
                  teamId: widget.teamId,
                  gameId: widget.gameId,
                  isLoading: _isLoadingStats,
                );
              },
            ),
            const SizedBox(height: 16.0),
            
            Row(
              children: [
                const Text('Individual Player Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_isLoadingStats)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16.0),
            FutureBuilder<List<GameEvent>>(
              future: widget.gameId != null 
                  ? _centralizedDataService.getCurrentGameEvents(widget.gameId!)
                  : _centralizedDataService.getAllCurrentGameEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isLoadingStats) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final gameEvents = snapshot.data ?? [];

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
            
            // Add goalie stats section if there are goalies
            if (goalies.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              FutureBuilder<List<GameEvent>>(
                future: widget.gameId != null 
                    ? _centralizedDataService.getCurrentGameEvents(widget.gameId!)
                    : _centralizedDataService.getAllCurrentGameEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !_isLoadingStats) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final gameEvents = snapshot.data ?? [];

                  return GoalieStatsWidget(
                    goalies: goalies,
                    gameEvents: gameEvents,
                    teamId: widget.teamId,
                    isLoading: _isLoadingStats,
                    showTitle: true,
                    showLegend: false,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
