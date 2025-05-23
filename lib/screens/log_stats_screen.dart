import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:hockey_stats_app/screens/edit_shot_list_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

class LogStatsScreen extends StatefulWidget {
  final String gameId;

  const LogStatsScreen({super.key, required this.gameId});

  @override
  State<LogStatsScreen> createState() => _LogStatsScreenState();
}

class _LogStatsScreenState extends State<LogStatsScreen> {
  int _selectedPeriod = 1;
  Game? _currentGame;
  bool _isLoadingScore = false;

  final SheetsService _sheetsService = SheetsService();
  GoogleSignInAccount? _currentUser;
  bool _isSigningIn = false;
  bool _isLoadingInitialData = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _checkSignInStatus();
  }

  Future<void> _checkSignInStatus() async {
    if (!mounted) return;
    _currentUser = _sheetsService.getCurrentUser();
    setState(() {});
  }

  Future<void> _loadInitialData() async {
    print('Loading initial data for game ${widget.gameId}');
    
    if (mounted) {
      setState(() {
        _isLoadingInitialData = true;
        _isLoadingScore = true;
      });
    }

    try {
      final gamesBox = Hive.box<Game>('games');
      final game = gamesBox.get(widget.gameId);
      print('Game loaded: ${game?.id}');
      
      if (game == null) {
        print('Game not found in Hive: ${widget.gameId}');
      }

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

  Future<void> _handleSync() async {
    if (!mounted) return;
    setState(() { 
      _isSigningIn = true;
      _isLoadingScore = true;
    });

    final result = await _sheetsService.syncPendingEvents();

    if (!mounted) return;

    String message;
    if (result['pending'] == -1) {
      message = 'Sync failed: Not authenticated.';
    } else if (result['failed']! > 0) {
      message = 'Sync complete with ${result['failed']} failures. ${result['success']} succeeded.';
      await _refreshScore();
    } else if (result['success']! > 0) {
      message = 'Sync complete: ${result['success']} events synced.';
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

  Future<void> _handleSyncFromSheets() async {
    if (!mounted) return;
    setState(() { 
      _isSigningIn = true;
      _isLoadingScore = true;
    });

    final result = await _sheetsService.syncDataFromSheets();

    if (!mounted) return;

    String message;
    if (result['success'] == true) {
      message = 'Sync complete: ${result['players']} players, ${result['games']} games, and ${result['events']} events synced.';
      
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

  Future<void> _refreshScore() async {
     if (!mounted) return;
     setState(() { _isLoadingScore = true; });
     try {
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

  Widget _buildLogButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required BuildContext context,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48.0, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8.0),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    String gameDetails = 'Game ID: ${widget.gameId}';
    if (_currentGame != null) {
      final dateStr = _currentGame!.date.toLocal().toString().split(' ')[0];
      gameDetails = '$dateStr vs ${_currentGame!.opponent}';
      if (_currentGame!.location != null && _currentGame!.location!.isNotEmpty) {
        gameDetails += ' at ${_currentGame!.location}';
      }
    }

    String periodTitle = 'Period ${_selectedPeriod == 4 ? "OT" : _selectedPeriod}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Stats'),
        actions: [
          if (_isLoadingInitialData)
             const Padding(
               padding: EdgeInsets.all(8.0),
               child: SizedBox(
                 width: 24, height: 24,
                 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,)
               ),
             )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit),
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
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'View Stats',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ViewStatsScreen(gameId: widget.gameId)),
                );
              },
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                _buildPeriodSelector(),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _buildLogButton(
                      icon: Icons.sports_hockey,
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
                      icon: Icons.sports,
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
                
                const SizedBox(height: 24.0),
                Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Row(
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
                        const SizedBox(height: 16),

                        if (_currentGame != null) ...[
                          Center(
                            child: TeamUtils.getGameLogos(
                              'Waxers',
                              _currentGame!.opponent,
                              size: 50.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
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
                          
                          ValueListenableBuilder(
                            valueListenable: Hive.box<GameEvent>('gameEvents').listenable(),
                            builder: (context, Box<GameEvent> box, _) {
                              final gameEvents = box.values.where((event) => event.gameId == widget.gameId).toList();
                              
                              print('Calculating shots for game ${widget.gameId}');
                              
                              final yourTeamShots = gameEvents.where((event) => 
                                event.eventType == 'Shot' && 
                                event.team == 'your_team'
                              ).length;
                              
                              final opponentShots = gameEvents.where((event) => 
                                event.eventType == 'Shot' && 
                                event.team == 'opponent'
                              ).length;
                              
                              for (var event in gameEvents.where((e) => e.eventType == 'Shot')) {
                                print('Shot Event:');
                                print('  ID: ${event.id}');
                                print('  Team: ${event.team}');
                                print('  IsGoal: ${event.isGoal}');
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

                        ] else ...[
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

                if (_currentUser != null) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: _isSigningIn ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).primaryColor)) : const Icon(Icons.sync),
                    label: const Text('Sync Data to Google Sheets'),
                    onPressed: _isSigningIn ? null : _handleSync,
                  ),
                ]
                ],
              ),
            ),
      ),
    );
  }

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
