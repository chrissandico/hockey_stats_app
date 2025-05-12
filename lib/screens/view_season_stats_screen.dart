import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart'; // For uploading to sheets

class ViewSeasonStatsScreen extends StatefulWidget {
  const ViewSeasonStatsScreen({super.key});

  @override
  State<ViewSeasonStatsScreen> createState() => _ViewSeasonStatsScreenState();
}

class _ViewSeasonStatsScreenState extends State<ViewSeasonStatsScreen> {
  List<PlayerSeasonStats> _seasonStats = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRefreshing = false; // For the refresh from sheets button

  Box<Player>? _playersBox;
  Box<GameEvent>? _gameEventsBox;
  final SheetsService _sheetsService = SheetsService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _playersBox = Hive.box<Player>('players');
      _gameEventsBox = Hive.box<GameEvent>('gameEvents'); // Ensure this is opened
      await _loadPlayerSeasonStatsFromHive(); 
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading data: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPlayerSeasonStatsFromHive() async {
    if (_playersBox == null || _gameEventsBox == null) {
      setState(() {
        _errorMessage = "Database not fully initialized.";
        _isLoading = false;
      });
      return;
    }

    final allPlayersList = _playersBox!.values.toList();
    final allEvents = _gameEventsBox!.values.toList();

    Map<String, PlayerSeasonStats> statsMap = {};

    // Initialize statsMap for all players from 'your_team'
    for (var player in allPlayersList) {
      if (player.teamId == 'your_team') { 
        statsMap[player.id] = PlayerSeasonStats(
          playerId: player.id,
          playerName: player.id, 
          playerJerseyNumber: player.jerseyNumber,
          playerPosition: player.position,
        );
      }
    }

    for (var event in allEvents) {
      // Ensure primary player is in statsMap (should be if they are from 'your_team')
      if (!statsMap.containsKey(event.primaryPlayerId) && event.team == 'Your Team') {
         final player = allPlayersList.firstWhere((p) => p.id == event.primaryPlayerId, orElse: () => Player(id: event.primaryPlayerId, jerseyNumber: 0, position: "N/A"));
         statsMap[event.primaryPlayerId] = PlayerSeasonStats(
            playerId: player.id,
            playerName: player.id, 
            playerJerseyNumber: player.jerseyNumber,
            playerPosition: player.position
         );
      }
      
      if (event.team == 'Your Team') {
        final playerStats = statsMap[event.primaryPlayerId];
        if (playerStats == null) continue;

        if (event.eventType == 'Shot') {
          playerStats.shots++;
          if (event.isGoal == true) {
            playerStats.goals++;
            // Plus for shooter's team on ice
            event.yourTeamPlayersOnIceIds?.forEach((playerId) {
              statsMap[playerId]?.plusMinus++;
            });
            // Assists
            if (event.assistPlayer1Id != null && event.assistPlayer1Id!.isNotEmpty && statsMap.containsKey(event.assistPlayer1Id)) {
              statsMap[event.assistPlayer1Id!]!.assists++;
            }
            if (event.assistPlayer2Id != null && event.assistPlayer2Id!.isNotEmpty && statsMap.containsKey(event.assistPlayer2Id)) {
              statsMap[event.assistPlayer2Id!]!.assists++;
            }
          }
        } else if (event.eventType == 'Penalty') {
          playerStats.penaltyMinutes += event.penaltyDuration ?? 0;
        }
      } else if (event.team == 'Opponent' && event.eventType == 'Shot' && event.isGoal == true) {
        // Minus for user's team on ice
        event.yourTeamPlayersOnIceIds?.forEach((playerId) {
          if (statsMap.containsKey(playerId)) {
            statsMap[playerId]!.plusMinus--;
          }
        });
      }
    }

    List<PlayerSeasonStats> aggregatedList = [];
    statsMap.forEach((playerId, stats) {
      // Player details (name, jersey, position) are already set during initialization of statsMap
      // or when a player was dynamically added.
      // No need to re-fetch from allPlayersList here if PlayerSeasonStats holds them.
      aggregatedList.add(stats);
    });

    // Sort by playerJerseyNumber in ascending order
    aggregatedList.sort((a, b) => a.playerJerseyNumber.compareTo(b.playerJerseyNumber));

    if(mounted){
      setState(() {
        _seasonStats = aggregatedList;
      });
    }
  }

  // Method _handleRefreshFromSheets removed as PlayerSeasonStats are no longer fetched from a separate sheet.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Season Stats'),
        actions: const [
          // Refresh button removed as per user request.
          // Stats are loaded on initState.
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                ))
              : _seasonStats.isEmpty && !_isLoading // Ensure not to show "No stats" during initial load if _loadData is async for sheets
                  ? const Center(child: Text('No season stats available. Try local refresh.')) // Updated message
                  : Column(
                      children: [
                        // "Refresh Stats from Sheets" button removed.
                        if (_seasonStats.isNotEmpty) // Only show table if stats are available
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
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
                                  child: DataTable(
                                    border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                                    columnSpacing: 15.0,
                                    headingRowHeight: 50,
                                    dataRowHeight: 45,
                                    columns: const [
                                      DataColumn(label: Text('#')),
                                      DataColumn(label: Text('POS')),
                                      DataColumn(label: Text('G'), numeric: true),
                                      DataColumn(label: Text('A'), numeric: true),
                                      DataColumn(label: Text('P'), numeric: true),
                                      DataColumn(label: Text('+/-'), numeric: true),
                                      DataColumn(label: Text('PIM'), numeric: true),
                                      DataColumn(label: Text('SOG'), numeric: true),
                                    ],
                                    rows: _seasonStats.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final stats = entry.value;
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
                                                stats.playerJerseyNumber.toString(),
                                                style: const TextStyle(fontSize: 15),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                              child: Text(
                                                stats.playerPosition ?? 'N/A',
                                                style: const TextStyle(fontSize: 15),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                              child: Text(
                                                stats.goals.toString(),
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
                                                stats.assists.toString(),
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
                                                stats.points.toString(),
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
                                                stats.plusMinus.toString(),
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: stats.plusMinus > 0 
                                                    ? Colors.green 
                                                    : stats.plusMinus < 0 
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
                                                stats.penaltyMinutes.toString(),
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
                                                stats.shots.toString(),
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
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
