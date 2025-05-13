import 'package:flutter/foundation.dart'; // Import for compute
import 'package:flutter/material.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:hockey_stats_app/screens/edit_shot_list_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';
import 'package:hockey_stats_app/services/sheets_service.dart'; // Import the service
import 'package:google_sign_in/google_sign_in.dart'; // Import for GoogleSignInAccount

// Helper function to calculate score
Map<String, int> _calculateScore(List<GameEvent> events) {
  print('Calculating score from ${events.length} events');
  
  int yourTeamScore = events.where((event) => 
    event.eventType == 'Shot' && 
    event.isGoal == true && 
    event.team == 'your_team'
  ).length;

  int opponentScore = events.where((event) => 
    event.eventType == 'Shot' && 
    event.isGoal == true && 
    event.team == 'opponent'
  ).length;

  print('Score calculation complete:');
  print('Your Team: $yourTeamScore');
  print('Opponent: $opponentScore');

  return {
    'Your Team': yourTeamScore,
    'Opponent': opponentScore,
  };
}

// This screen will display the logging buttons after a game isselected.
// It receives the selected gameId.
class LogStatsScreen extends StatefulWidget {
  final String gameId; // The ID of the currently selected game

  const LogStatsScreen({super.key, required this.gameId});

  @override
  State<LogStatsScreen> createState() => _LogStatsScreenState();
}

class _LogStatsScreenState extends State<LogStatsScreen> {
  // State variables
  int _selectedPeriod = 1; // Default to period 1
  Game? _currentGame;
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
    _checkSignInStatus();
    // _isSigningIn = false; // This flag is primarily for the sync button's loading state now
  }

  // Check sign-in status
  Future<void> _checkSignInStatus() async {
    if (!mounted) return;
    _currentUser = _sheetsService.getCurrentUser();
    setState(() {});
  }

  // Load initial game data
  Future<void> _loadInitialData() async {
    print('Loading initial data for game ${widget.gameId}');
    
    // Ensure initial state reflects loading
    if (mounted) {
      setState(() {
        _isLoadingInitialData = true;
        _isLoadingScore = true;
      });
    }

    try {
      // Load game details
      final gamesBox = Hive.box<Game>('games');
      final game = gamesBox.get(widget.gameId);
      print('Game loaded: ${game?.id}');
      
      if (game == null) {
        print('Game not found in Hive: ${widget.gameId}');
      }

      // Update state after loading is complete
      if (mounted) {
        setState(() {
          _currentGame = game;
          _isLoadingInitialData = false;
          _isLoadingScore = false;
        });
      }
    } catch (e) {
      print('Error in _loadInitialData: $e');
      if (mounted) {
        setState(() {
          _isLoadingInitialData = false;
          _isLoadingScore = false;
        });
      }
    }
  }

  // // Check initial sign-in status (Keep the method in case needed later, but don't call from initState)
  // Future<void> _checkSignInStatus() async {
  //   if (!mounted) return;
  //   setState(() { _isSigningIn = true; }); // Show loading indicator
  //   await _sheetsService.signInSilently();
  //   if (!mounted) return;
  //   setState(() {
  //     _currentUser = _sheetsService.getCurrentUser();
  //     _isSigningIn = false;
  //   });
  // }

  // Handle Sign In button press
  Future<void> _handleSignIn() async {
    if (!mounted) return;
    setState(() { _isSigningIn = true; });
    
    bool signInSuccess = await _sheetsService.signIn();
    
    if (!mounted) return;
    setState(() {
      _currentUser = _sheetsService.getCurrentUser();
      _isSigningIn = false;
    });
    
    if (signInSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed. Please try again.')),
      );
    }
  }

  // Show sign-out confirmation dialog
  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out? You won\'t be able to sync data until you sign in again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleSignOut();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  // Handle sign-out process
  Future<void> _handleSignOut() async {
    if (!mounted) return;
    setState(() { _isSigningIn = true; });
    
    await _sheetsService.signOut();
    
    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _isSigningIn = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out successfully')),
    );
  }

  // Handle Sync button press
  Future<void> _handleSync() async {
    if (!mounted) return;
    setState(() { 
      _isSigningIn = true;
      _isLoadingScore = true; // Show loading indicator for score
    });

    final result = await _sheetsService.syncPendingEvents();

    if (!mounted) return;

    // Show feedback based on sync result
    String message;
    if (result['pending'] == -1) {
      message = 'Sync failed: Not authenticated.';
    } else if (result['failed']! > 0) {
      message = 'Sync complete with ${result['failed']} failures. ${result['success']} succeeded.';
      // Refresh score even if some failed
      await _refreshScore();
    } else if (result['success']! > 0) {
      message = 'Sync complete: ${result['success']} events synced.';
      // Refresh score on success
      await _refreshScore();
    } else {
      message = 'No pending events to sync.';
    }

    if (!mounted) return;
    setState(() {
      _isSigningIn = false;
      _isLoadingScore = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Handle Sync from Sheets button press
  Future<void> _handleSyncFromSheets() async {
    if (!mounted) return;
    setState(() { 
      _isSigningIn = true;
      _isLoadingScore = true; // Show loading indicator for score
    });

    final result = await _sheetsService.syncDataFromSheets();

    if (!mounted) return;

    // Show feedback based on sync result
    String message;
    if (result['success'] == true) {
      message = 'Sync complete: ${result['players']} players, ${result['games']} games, and ${result['events']} events synced.';
      
      // Reload game data and refresh score
      await _loadInitialData();
      await _refreshScore();
      
    } else {
      message = 'Sync failed: ${result['message']}';
    }

    if (!mounted) return;
    setState(() {
      _isSigningIn = false;
      _isLoadingScore = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  // Build the period selector UI
  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0), // const added
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text( // const added
            'Select Period:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0), // const added
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
        padding: const EdgeInsets.symmetric(horizontal: 4.0), // const added
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedPeriod = period;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
            foregroundColor: isSelected ? Colors.white : null,
            padding: const EdgeInsets.symmetric(vertical: 12.0), // const added
          ),
          child: Text(label ?? 'P$period'),
        ),
      ),
    );
  }

  // Remove unused _getGameScore method since we're using ValueListenableBuilder

  // Method to refresh score after an event is logged
  Future<void> _refreshScore() async {
     if (!mounted) return;
     setState(() { _isLoadingScore = true; });
     try {
        // No need to update _currentScore since we're using ValueListenableBuilder
        if (mounted) {
           setState(() {
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

  // Helper method to build styled logging buttons
  Widget _buildLogButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required BuildContext context, // Added context for theme access if needed
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0), // const added
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0), // const added
            // backgroundColor: Theme.of(context).colorScheme.surfaceVariant, // Example background
            // foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, // Example foreground
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0), // Rounded corners
            ),
            elevation: 3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fit content
            children: <Widget>[
              Icon(icon, size: 48.0, color: Theme.of(context).colorScheme.primary), // Larger icon, themed color
              const SizedBox(height: 8.0), // const added
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant, // Themed text color
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        title: const Text('Track Stats'), // const added
        actions: [
           // Show loading indicator during initial load
          if (_isLoadingInitialData)
             const Padding( // const added
               padding: EdgeInsets.all(8.0), // const added
               child: SizedBox(
                 width: 24, height: 24,
                 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,)
               ),
             )
          else ...[ // Show normal actions only after load
            // Edit Shots Button
            IconButton(
              icon: const Icon(Icons.edit), // const added
              tooltip: 'Edit Logged Shots',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditShotListScreen(gameId: widget.gameId)),
                ).then((_) {
                  print('Returned from EditShotListScreen, refreshing score...');
                  _refreshScore().then((_) {
                    print('Score refresh complete');
                  });
                });
              },
            ),
            // View Stats Button
            IconButton(
              icon: const Icon(Icons.bar_chart), // const added
              tooltip: 'View Stats',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ViewStatsScreen(gameId: widget.gameId)),
                );
              },
            ),
            // Add Sign-In/Sign-Out Button
            _buildAuthIndicator(),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // const added
        child: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator()) // const added
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                // Period selection UI
                _buildPeriodSelector(),

                const SizedBox(height: 24), // const added

                // Buttons to navigate to specific logging screens (New Layout)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _buildLogButton(
                      icon: Icons.sports_hockey, // Hockey stick icon
                      label: 'Log Shot',
                      context: context,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LogShotScreen(
                              gameId: widget.gameId,
                              period: _selectedPeriod,
                            ),
                          ),
                        ).then((value) {
                          print('Returned from LogShotScreen, refreshing score...');
                          _refreshScore().then((_) {
                            print('Score refresh complete');
                            if (value != null && value is int) {
                              setState(() {
                                _selectedPeriod = value;
                              });
                            }
                          });
                        });
                      },
                    ),
                    _buildLogButton(
                      icon: Icons.sports, // Whistle icon (using a generic sports icon)
                      label: 'Log Penalty',
                      context: context,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LogPenaltyScreen(
                              gameId: widget.gameId,
                              period: _selectedPeriod,
                            ),
                          ),
                        ).then((value) {
                          print('Returned from LogPenaltyScreen, refreshing score...');
                          _refreshScore().then((_) {
                            print('Score refresh complete');
                            if (value != null && value is int) {
                              setState(() {
                                _selectedPeriod = value;
                              });
                            }
                          });
                        });
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 24.0), // const added
                // Game details section with enhanced display
                Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0), // const added
                    child: Column(
                      children: [
                        const Row( // const added
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Game Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16), // const added

                        // Team logos and game info
                        if (_currentGame != null) ...[
                          // Team logos
                          Center(
                            child: TeamUtils.getGameLogos(
                              'Waxers', // Your team name
                              _currentGame!.opponent,
                              size: 50.0,
                            ),
                          ),
                          const SizedBox(height: 8), // const added
                          
  // Display current game score
  ValueListenableBuilder(
    valueListenable: Hive.box<GameEvent>('gameEvents').listenable(),
    builder: (context, Box<GameEvent> box, _) {
      final gameEvents = box.values.where((event) => event.gameId == widget.gameId).toList();
      final score = _calculateScore(gameEvents);
      
      return Center(
        child: _isLoadingScore
            ? const SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 3))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${score['Your Team']}',
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
                    '${score['Opponent']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
      );
    }
  ),
                          const SizedBox(height: 8),
                          
                          // Display shots on goal
                          ValueListenableBuilder(
                            valueListenable: Hive.box<GameEvent>('gameEvents').listenable(),
                            builder: (context, Box<GameEvent> box, _) {
                              final gameEvents = box.values.where((event) => event.gameId == widget.gameId).toList();
                              
                              // Calculate shots
                              print('Calculating shots for game ${widget.gameId}');
                              
                              final yourTeamShots = gameEvents.where((event) => 
                                event.eventType == 'Shot' && 
                                event.team == 'your_team'
                              ).length;
                              
                              final opponentShots = gameEvents.where((event) => 
                                event.eventType == 'Shot' && 
                                event.team == 'opponent'
                              ).length;
                              
                              // Debug print each shot
                              for (var event in gameEvents.where((e) => e.eventType == 'Shot')) {
                                print('Shot Event:');
                                print('  ID: ${event.id}');
                                print('  Team: ${event.team}');
                                print('  IsGoal (raw): ${event.isGoal}');
                                print('  IsGoal (wasGoal): ${event.wasGoal}');
                              }
                              
                              print('Shot totals - Your Team: $yourTeamShots, Opponent: $opponentShots');

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$yourTeamShots',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const Text(
                                    ' shots ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$opponentShots',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              );
                            }
                          ),
                          const SizedBox(height: 16),

                          // Date row
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.blue), // const added
                              const SizedBox(width: 8), // const added
                              Text(
                                'Date: ${_currentGame!.date.toLocal().toString().split(' ')[0]}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), // const added
                              ),
                            ],
                          ),
                          const SizedBox(height: 8), // const added

                          // Opponent row
                          Row(
                            children: [
                              const Icon(Icons.sports_hockey, color: Colors.blue), // const added
                              const SizedBox(width: 8), // const added
                              Expanded(
                                child: Text(
                                  'Opponent: ${_currentGame!.opponent}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), // const added
                                ),
                              ),
                            ],
                          ),

                          // Location row (if available) - REMOVED as per user request
                        ] else ...[
                          // If game details couldn't be loaded
                          Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.orange), // const added
                              const SizedBox(width: 8), // const added
                              Text(
                                'Game ID: ${widget.gameId}',
                                style: const TextStyle(fontSize: 16), // const added
                              ),
                            ],
                          ),
                          const SizedBox(height: 4), // const added
                          const Text( // const added
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
                const SizedBox(height: 16), // const added

                if (_currentUser != null) ...[
                  const SizedBox(height: 10), // const added
                  ElevatedButton.icon(
                    icon: _isSigningIn ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).primaryColor)) : const Icon(Icons.sync), // const removed from SizedBox
                    label: const Text('Sync Data to Google Sheets'), // const added
                    onPressed: _isSigningIn ? null : _handleSync,
                  ),
                ]
                ],
              ),
            ),
      ),
    );
  }

  // Build the auth indicator based on sign-in state
  Widget _buildAuthIndicator() {
    return IconButton(
      icon: _currentUser == null
          ? const Icon(Icons.account_circle, color: Colors.grey)
          : const Icon(Icons.account_circle, color: Colors.green),
      tooltip: _currentUser == null
          ? 'Sign in with Google'
          : 'Signed in as ${_currentUser!.email}. Tap to sign out.',
      onPressed: _isSigningIn
          ? null
          : _currentUser == null
              ? _handleSignIn
              : _showSignOutDialog,
    );
  }
}
