import 'package:flutter/material.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';

// This screen will display the logging buttons after a game is selected.
// It receives the selected gameId.
class LogStatsScreen extends StatefulWidget {
  final String gameId; // The ID of the currently selected game

  const LogStatsScreen({super.key, required this.gameId});

  @override
  _LogStatsScreenState createState() => _LogStatsScreenState();
}

class _LogStatsScreenState extends State<LogStatsScreen> {
  // State variables
  int _selectedPeriod = 1; // Default to period 1
  Game? _currentGame;
  Map<String, int> _currentScore = {'Your Team': 0, 'Opponent': 0};
  bool _isLoadingScore = false;

  @override
  void initState() {
    super.initState();
    _loadGameDetails();
    _updateGameScore();
  }

  // Load game details from Hive
  void _loadGameDetails() {
    final gamesBox = Hive.box<Game>('games');
    try {
      setState(() {
        _currentGame = gamesBox.values.firstWhere(
          (game) => game.id == widget.gameId,
        );
      });
    } catch (e) {
      // If no game is found, _currentGame remains null
      print('Game not found: ${widget.gameId}');
    }
  }

  // Build the period selector UI
  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Period:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPeriodButton(1),
              _buildPeriodButton(2),
              _buildPeriodButton(3),
              _buildPeriodButton(4, label: 'OT'),
            ],
          ),
        ],
      ),
    );
  }

  // Build individual period button
  Widget _buildPeriodButton(int period, {String? label}) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedPeriod = period;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
            foregroundColor: isSelected ? Colors.white : null,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
          ),
          child: Text(label ?? 'P$period'),
        ),
      ),
    );
  }

  // Display current period indicator
  Widget _buildPeriodIndicator() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColorLight,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Theme.of(context).primaryColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8.0),
          Text(
            'Current Period: ${_selectedPeriod == 4 ? 'OT' : _selectedPeriod}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  // Update the game score state
  void _updateGameScore() {
    setState(() {
      _isLoadingScore = true;
    });
    
    _getGameScore().then((scores) {
      setState(() {
        _currentScore = scores;
        _isLoadingScore = false;
      });
    }).catchError((error) {
      setState(() {
        _isLoadingScore = false;
      });
      print('Error loading game score: $error');
    });
  }
  
  // Calculate the current game score
  Future<Map<String, int>> _getGameScore() async {
    // Access the gameEvents box
    final gameEventsBox = Hive.box<GameEvent>('gameEvents');
    
    // Get all game events for the current game
    final gameEvents = gameEventsBox.values.where((event) => event.gameId == widget.gameId).toList();
    
    // Count goals for each team
    int yourTeamScore = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.team == 'Your Team'
    ).length;
    
    int opponentScore = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.team == 'Opponent'
    ).length;
    
    // Return scores as a map
    return {
      'Your Team': yourTeamScore,
      'Opponent': opponentScore,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Format game details for display
    String gameDetails = 'Game ID: ${widget.gameId}';
    if (_currentGame != null) {
      // Format the date to a readable string
      final dateStr = _currentGame!.date.toLocal().toString().split(' ')[0];
      gameDetails = '$dateStr vs ${_currentGame!.opponent}';
      if (_currentGame!.location != null && _currentGame!.location!.isNotEmpty) {
        gameDetails += ' at ${_currentGame!.location}';
      }
    }
    
    // Create a title for the current period
    String periodTitle = 'Period ${_selectedPeriod == 4 ? "OT" : _selectedPeriod}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Stats'), // Title indicating tracking mode
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ViewStatsScreen(gameId: widget.gameId)),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            // Game details section with enhanced display
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Game Details',
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Team logos
                    if (_currentGame != null) ...[
                      Center(
                        child: TeamUtils.getGameLogos(
                          'Waxers', // Your team name
                          _currentGame!.opponent,
                          size: 50.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Display current game score
                      Center(
                        child: _isLoadingScore
                            ? const CircularProgressIndicator()
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${_currentScore['Your Team']}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const Text(
                                    ' - ',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_currentScore['Opponent']}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Game date and opponent
                    if (_currentGame != null) ...[
                      // Date row
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Date: ${_currentGame!.date.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Opponent row
                      Row(
                        children: [
                          const Icon(Icons.sports_hockey, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Opponent: ${_currentGame!.opponent}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      
                      // Location row (if available)
                      if (_currentGame!.location != null && _currentGame!.location!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Location: ${_currentGame!.location}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      // If game details couldn't be loaded
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Game ID: ${widget.gameId}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Game details not found',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Period selection UI
            _buildPeriodSelector(),
            
            // Current period indicator
            Center(child: _buildPeriodIndicator()),
            
            const SizedBox(height: 24),

            // Buttons to navigate to specific logging screens
            ElevatedButton(
              onPressed: () {
                // Navigate to LogShotScreen, passing the selected gameId
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LogShotScreen(
                      gameId: widget.gameId,
                      period: _selectedPeriod,
                    ),
                  ),
                ).then((value) {
                  // Update score when returning from LogShotScreen
                  _updateGameScore();
                  
                  // If LogShotScreen returns a period value, update our state
                  if (value != null && value is int) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                  }
                });
              },
              child: const Text('Log Shot'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Navigate to LogPenaltyScreen, passing the selected gameId
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LogPenaltyScreen(
                      gameId: widget.gameId,
                      period: _selectedPeriod,
                    ),
                  ),
                ).then((value) {
                  // Update score when returning from LogPenaltyScreen
                  _updateGameScore();
                  
                  // If LogPenaltyScreen returns a period value, update our state
                  if (value != null && value is int) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                  }
                });
              },
              child: const Text('Log Penalty'),
            ),
            // TODO: Add button for View Local Stats (UF-5)
            // TODO: Add button for Sync Data (UF-4)
            ],
          ),
        ),
      ),
    );
  }
}
