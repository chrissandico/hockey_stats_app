import 'package:flutter/material.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';
import 'package:hockey_stats_app/services/sheets_service.dart'; // Import the service
import 'package:google_sign_in/google_sign_in.dart'; // Import for GoogleSignInAccount

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
  bool _isLoadingScore = false; // Keep for score updates after initial load if needed

  // Add instance of the service and state for authentication
  final SheetsService _sheetsService = SheetsService();
  GoogleSignInAccount? _currentUser;
  bool _isSigningIn = false; // Used for both sign-in and manual sync
  bool _isLoadingInitialData = true; // Flag for initial data load

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Load data asynchronously
    // Initialize auth state directly
    _currentUser = _sheetsService.getCurrentUser();
    _isSigningIn = false;
  }

  // Load initial game data and score asynchronously
  Future<void> _loadInitialData() async {
    // Ensure initial state reflects loading
    if (mounted) {
      setState(() {
        _isLoadingInitialData = true;
        _isLoadingScore = true;
      });
    }

    // Load game details
    final gamesBox = Hive.box<Game>('games');
    Game? game;
    try {
      // Use await for potential async operations if Hive access becomes complex,
      // but firstWhere is typically synchronous. Run calculation off-thread if needed.
      game = gamesBox.values.firstWhere((g) => g.id == widget.gameId);
    } catch (e) {
      print('Game not found: ${widget.gameId}');
    }

    // Load score
     Map<String, int> score = {'Your Team': 0, 'Opponent': 0};
    try {
       // _getGameScore can remain sync if Hive reads are fast enough
       // If it becomes slow, make it async or run in an isolate.
       score = await _getGameScore();
    } catch(e) {
       print('Error loading game score: $e');
    }

    // Update state after loading is complete
    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _currentGame = game;
        _currentScore = score;
        _isLoadingInitialData = false;
        _isLoadingScore = false;
      });
    }
  }

  // Check initial sign-in status (Keep the method in case needed later, but don't call from initState)
  Future<void> _checkSignInStatus() async {
    if (!mounted) return;
    setState(() { _isSigningIn = true; }); // Show loading indicator
    await _sheetsService.signInSilently();
    if (!mounted) return;
    setState(() {
      _currentUser = _sheetsService.getCurrentUser();
      _isSigningIn = false;
    });
  }

  // Handle Sign In button press
  Future<void> _handleSignIn() async {
    // Ensure context is still valid if async operation takes time
    if (!mounted) return;
    setState(() { _isSigningIn = true; });
    bool success = await _sheetsService.signIn();
    // Ensure context is still valid after await
    if (!mounted) return;
    if (success) {
      setState(() {
        _currentUser = _sheetsService.getCurrentUser();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed in as ${_currentUser?.displayName ?? 'Unknown'}')),
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in failed.')),
      );
    }
     // Also reset _isSigningIn if sign in fails
     if (!success) {
       setState(() { _isSigningIn = false; });
     } else {
       setState(() { _isSigningIn = false; }); // Already setting above, but ensure it's false
     }
  }

  // Handle Sign Out button press
  Future<void> _handleSignOut() async {
    await _sheetsService.signOut();
    if (!mounted) return;
    setState(() {
      _currentUser = null;
    });
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out.')),
    );
     // Reset signing in flag if sign out happens while syncing (edge case)
     setState(() { _isSigningIn = false; });
  }

  // Handle Sync button press
  Future<void> _handleSync() async {
    if (!mounted) return;
    setState(() { _isSigningIn = true; }); // Use _isSigningIn to show loading on button

    final result = await _sheetsService.syncPendingEvents();

    if (!mounted) return; // Check again after await

    setState(() { _isSigningIn = false; });

    // Show feedback based on sync result
    String message;
    if (result['pending'] == -1) {
      message = 'Sync failed: Not authenticated.';
    } else if (result['failed']! > 0) {
      message = 'Sync complete with ${result['failed']} failures. ${result['success']} succeeded.';
    } else if (result['success']! > 0) {
      message = 'Sync complete: ${result['success']} events synced.';
    } else {
      message = 'No pending events to sync.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Handle Sync from Sheets button press
  Future<void> _handleSyncFromSheets() async {
    if (!mounted) return;
    setState(() { _isSigningIn = true; }); // Use _isSigningIn to show loading on button

    final result = await _sheetsService.syncDataFromSheets();

    if (!mounted) return; // Check again after await

    setState(() { _isSigningIn = false; });

    // Show feedback based on sync result
    String message;
    if (result['success'] == true) {
      message = 'Sync complete: ${result['players']} players and ${result['games']} games synced.';
      
      // Reload current game data if we're viewing a game
      if (_currentGame != null) {
        _loadInitialData(); // Reload game details and score
      }
    } else {
      message = 'Sync failed: ${result['message']}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  // Calculate the current game score (can remain synchronous if Hive reads are fast enough)
  Future<Map<String, int>> _getGameScore() async {
    // Access the gameEvents box
    final gameEventsBox = Hive.box<GameEvent>('gameEvents');

    // Get all game events for the current game
    // Consider running this in compute() if it becomes slow
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

  // Method to refresh score after an event is logged
  Future<void> _refreshScore() async {
     if (!mounted) return;
     setState(() { _isLoadingScore = true; });
     try {
        final score = await _getGameScore();
        if (mounted) {
           setState(() {
              _currentScore = score;
              _isLoadingScore = false;
           });
        }
     } catch (e) {
        print('Error refreshing score: $e');
        if (mounted) {
           setState(() { _isLoadingScore = false; });
        }
     }
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
           // Show loading indicator during initial load
          if (_isLoadingInitialData)
             const Padding(
               padding: EdgeInsets.all(8.0),
               child: SizedBox(
                 width: 24, height: 24,
                 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,)
               ),
             )
          else ...[ // Show normal actions only after load
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ViewStatsScreen(gameId: widget.gameId)),
                );
              },
            ),
            // Add Sign-In/Sign-Out Button
            _buildAuthButton(),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator for body
          : SingleChildScrollView(
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
                            child: _isLoadingScore // Use separate flag for score updates
                                ? const SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 3,)) // Smaller indicator for score
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
                      _refreshScore(); // Use refresh method

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
                      _refreshScore(); // Use refresh method

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
                // TODO: Add button for Sync Data (UF-4) - Should be enabled only when signed in
                if (_currentUser != null) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: _isSigningIn ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).primaryColor)) : const Icon(Icons.sync),
                    label: const Text('Sync Data to Google Sheets'),
                    onPressed: _isSigningIn ? null : _handleSync,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: _isSigningIn ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).primaryColor)) : const Icon(Icons.download),
                    label: const Text('Sync Roster & Schedule from Sheets'),
                    onPressed: _isSigningIn ? null : _handleSyncFromSheets,
                  ),
                ]
                ],
              ),
            ),
      ),
    );
  }

  // Build the Auth button based on sign-in state
  Widget _buildAuthButton() {
    if (_isSigningIn) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 24, // Consistent size with IconButton
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_currentUser != null) {
      // Show Sign Out button
      return IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Sign Out (${_currentUser!.email})',
        onPressed: _handleSignOut,
      );
    } else {
      // Show Sign In button
      return IconButton(
        icon: const Icon(Icons.login),
        tooltip: 'Sign In with Google',
        onPressed: _handleSignIn,
      );
    }
  }

}
