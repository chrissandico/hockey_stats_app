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
      _gameEventsBox = Hive.box<GameEvent>('gameEvents');
      await _aggregateStats();
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

  Future<void> _aggregateStats() async {
    if (_playersBox == null || _gameEventsBox == null) {
      setState(() {
        _errorMessage = "Database not initialized.";
        _isLoading = false;
      });
      return;
    }

    final allPlayersList = _playersBox!.values.toList();
    final allEvents = _gameEventsBox!.values.toList();

    Map<String, PlayerSeasonStats> statsMap = {};
    Map<String, Set<String>> gamesPlayedMap = {}; // PlayerId -> Set of GameIds

    // Initialize statsMap for all players from 'your_team'
    for (var player in allPlayersList) {
      if (player.teamId == 'your_team') { // Assuming 'your_team' is the identifier for the user's team
        statsMap[player.id] = PlayerSeasonStats(
          playerId: player.id,
          playerName: player.id, // Placeholder, will be updated
          playerJerseyNumber: player.jerseyNumber,
          playerPosition: player.position, // Populate position
        );
        gamesPlayedMap[player.id] = {};
      }
    }

    for (var event in allEvents) {
      // Ensure primary player is in statsMap (should be if they are from 'your_team')
      if (!statsMap.containsKey(event.primaryPlayerId) && event.team == 'Your Team') {
         // This case should ideally not happen if all 'your_team' players are pre-loaded.
         // However, as a fallback, find the player and add them.
         final player = allPlayersList.firstWhere((p) => p.id == event.primaryPlayerId, orElse: () => Player(id: event.primaryPlayerId, jerseyNumber: 0, position: "N/A")); // Dummy player if not found
         statsMap[event.primaryPlayerId] = PlayerSeasonStats(
            playerId: player.id,
            playerName: player.id, 
            playerJerseyNumber: player.jerseyNumber,
            playerPosition: player.position // Populate position for fallback
         );
         gamesPlayedMap[event.primaryPlayerId] = {};
      }
      
      // Track games played for the primary player of an event if they are on 'Your Team'
      if (event.team == 'Your Team' && statsMap.containsKey(event.primaryPlayerId)) {
        gamesPlayedMap[event.primaryPlayerId]!.add(event.gameId);
      }


      if (event.team == 'Your Team') {
        final playerStats = statsMap[event.primaryPlayerId];
        if (playerStats == null) continue; // Skip if player not found (e.g. not 'your_team')

        if (event.eventType == 'Shot') {
          playerStats.shots++;
          if (event.isGoal == true) {
            playerStats.goals++;
            // Plus for shooter's team on ice
            event.yourTeamPlayersOnIceIds?.forEach((playerId) {
              statsMap[playerId]?.plusMinus++;
            });
            // Assists
            if (event.assistPlayer1Id != null && statsMap.containsKey(event.assistPlayer1Id)) {
              statsMap[event.assistPlayer1Id!]!.assists++;
               gamesPlayedMap[event.assistPlayer1Id!]!.add(event.gameId); // Also track game for assister
            }
            if (event.assistPlayer2Id != null && statsMap.containsKey(event.assistPlayer2Id)) {
              statsMap[event.assistPlayer2Id!]!.assists++;
              gamesPlayedMap[event.assistPlayer2Id!]!.add(event.gameId); // Also track game for assister
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
            gamesPlayedMap[playerId]!.add(event.gameId); // Track game for players on ice for opponent goal
          }
        });
      }
    }

    List<PlayerSeasonStats> aggregatedList = [];
    statsMap.forEach((playerId, stats) {
      final player = allPlayersList.firstWhere((p) => p.id == playerId, orElse: () => Player(id: playerId, jerseyNumber: 0, position: "N/A")); // Fallback
      stats.playerName = player.id; // Or a proper name field if it exists
      stats.playerJerseyNumber = player.jerseyNumber;
      stats.playerPosition = player.position; // Ensure position is set from the definitive Player object
      stats.gamesPlayed = gamesPlayedMap[playerId]?.length ?? 0;
      aggregatedList.add(stats);
    });

    // Sort by playerJerseyNumber in ascending order
    aggregatedList.sort((a, b) => a.playerJerseyNumber.compareTo(b.playerJerseyNumber));

    setState(() {
      _seasonStats = aggregatedList;
    });
  }

  Future<void> _handleRefreshFromSheets() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    try {
      final List<PlayerSeasonStats>? fetchedStats = await _sheetsService.fetchPlayerSeasonStatsFromSheets();
      if (fetchedStats != null) {
        // Sort by playerJerseyNumber in ascending order, similar to _aggregateStats
        fetchedStats.sort((a, b) => a.playerJerseyNumber.compareTo(b.playerJerseyNumber));
        setState(() {
          _seasonStats = fetchedStats;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player stats refreshed from Google Sheets!')),
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch stats from Google Sheets.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error refreshing stats: ${e.toString()}";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Season Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isRefreshing ? null : _loadData, // Use _isRefreshing
            tooltip: 'Refresh Stats (Local)', // Clarify this is local aggregation
          ),
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
                  ? const Center(child: Text('No season stats available. Try refreshing from Sheets.'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton.icon(
                            icon: _isRefreshing
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.download), // Changed icon
                            label: const Text('Refresh Stats from Sheets'), // Changed label
                            onPressed: _isRefreshing ? null : _handleRefreshFromSheets, // Changed handler
                          ),
                        ),
                        if (_seasonStats.isNotEmpty) // Only show table if stats are available
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 15.0,
                                columns: const [
                                  DataColumn(label: Text('#')), // Renamed column
                                  DataColumn(label: Text('POS')), // New POS column
                                  DataColumn(label: Text('GP'), numeric: true),
                                  DataColumn(label: Text('G'), numeric: true),
                                  DataColumn(label: Text('A'), numeric: true),
                                  DataColumn(label: Text('P'), numeric: true),
                                  DataColumn(label: Text('SOG'), numeric: true),
                                  DataColumn(label: Text('PIM'), numeric: true),
                                  DataColumn(label: Text('+/-'), numeric: true),
                                ],
                                rows: _seasonStats.map((stats) {
                                  return DataRow(cells: [
                                    DataCell(Text(stats.playerJerseyNumber.toString())),
                                    DataCell(Text(stats.playerPosition ?? 'N/A')), // Display position
                                    DataCell(Text(stats.gamesPlayed.toString())),
                                    DataCell(Text(stats.goals.toString())),
                                    DataCell(Text(stats.assists.toString())),
                                    DataCell(Text(stats.points.toString())),
                                    DataCell(Text(stats.shots.toString())),
                                    DataCell(Text(stats.penaltyMinutes.toString())),
                                    DataCell(Text(stats.plusMinus.toString())),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
