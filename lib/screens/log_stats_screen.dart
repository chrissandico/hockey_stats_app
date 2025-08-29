import 'package:flutter/material.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:hockey_stats_app/screens/edit_shot_list_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';

Map<String, int> _calculateScore(List<GameEvent> events, String teamId) {
  print('Calculating score from ${events.length} events');
  
  int yourTeamScore = events.where((event) => 
    event.eventType == 'Shot' && 
    event.isGoal == true && 
    event.team == teamId
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
  final String teamId;

  const LogStatsScreen({super.key, required this.gameId, required this.teamId});

  @override
  State<LogStatsScreen> createState() => _LogStatsScreenState();
}

class _LogStatsScreenState extends State<LogStatsScreen> {
  int _selectedPeriod = 1;
  Game? _currentGame;
  bool _isLoadingScore = false;

  final SheetsService _sheetsService = SheetsService();
  String? _currentUser; // Changed from GoogleSignInAccount? to String?
  bool _isSigningIn = false;
  bool _isLoadingInitialData = true;
  
  // Players on ice tracking
  List<Player> _yourTeamPlayers = [];
  List<Player> _selectedPlayersOnIce = [];
  bool _isLoadingPlayers = false;
  
  // Attendance tracking
  Set<String> _absentPlayerIds = {}; // Track absent players
  bool _isLoadingAttendance = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _checkSignInStatus();
    _loadPlayers();
    _loadAttendanceData();
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
  
  Future<void> _loadPlayers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingPlayers = true;
    });
    
    try {
      final playersBox = Hive.box<Player>('players');
      // Filter out goalies (players with position "G")
      final players = playersBox.values
          .where((p) => p.teamId == widget.teamId && p.position != 'G')
          .toList();
      
      if (mounted) {
        setState(() {
          _yourTeamPlayers = players;
          _isLoadingPlayers = false;
        });
      }
    } catch (e) {
      print('Error loading players: $e');
      if (mounted) {
        setState(() {
          _isLoadingPlayers = false;
        });
      }
    }
  }
  
  // Load attendance data for the current game
  Future<void> _loadAttendanceData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingAttendance = true;
    });
    
    try {
      final rosterBox = Hive.box<GameRoster>('gameRoster');
      final existingRoster = rosterBox.values
          .where((r) => r.gameId == widget.gameId)
          .toList();

      if (existingRoster.isNotEmpty) {
        setState(() {
          _absentPlayerIds = existingRoster
              .where((r) => r.status == 'Absent')
              .map((r) => r.playerId)
              .toSet();
        });
      }
    } catch (e) {
      print('Error loading attendance data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAttendance = false;
        });
      }
    }
  }
  
  // Check if a player is absent
  bool _isPlayerAbsent(Player player) {
    return _absentPlayerIds.contains(player.id);
  }
  
  List<Player> _getForwards() {
    final forwards = _yourTeamPlayers.where((player) => 
      player.position == 'C' || 
      player.position == 'LW' || 
      player.position == 'RW' ||
      player.position == 'F'
    ).toList();
    
    // Sort by jersey number
    forwards.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    return forwards;
  }
  
  List<Player> _getDefensemen() {
    final defensemen = _yourTeamPlayers.where((player) => 
      player.position == 'D' || 
      player.position == 'LD' || 
      player.position == 'RD'
    ).toList();
    
    // Sort by jersey number
    defensemen.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    return defensemen;
  }
  
  void _togglePlayerOnIce(Player player) {
    // Don't allow selecting absent players
    if (_isPlayerAbsent(player)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot select absent player'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      if (_selectedPlayersOnIce.contains(player)) {
        _selectedPlayersOnIce.remove(player);
      } else {
        if (_selectedPlayersOnIce.length < 5) {
          _selectedPlayersOnIce.add(player);
        } else {
          // Show a snackbar if trying to add more than 5 players
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 5 players can be on ice'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }
  
  void _clearPlayersOnIce() {
    setState(() {
      _selectedPlayersOnIce.clear();
    });
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
                  MaterialPageRoute(builder: (context) => EditShotListScreen(gameId: widget.gameId, teamId: widget.teamId)),
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
                  MaterialPageRoute(builder: (context) => ViewStatsScreen(gameId: widget.gameId, teamId: widget.teamId)),
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
                
                // Players On Ice Panel
                _buildPlayersOnIcePanel(),

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
                              teamId: widget.teamId,
                              playersOnIce: _selectedPlayersOnIce,
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
                              teamId: widget.teamId,
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
                              final score = _calculateScore(gameEvents, widget.teamId);
                              
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
                                event.team == widget.teamId
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
          : 'Signed in as $_currentUser. Tap to sign out.',
      onPressed: _isSigningIn
          ? null
          : _currentUser == null
              ? _handleSignIn
              : _showSignOutDialog,
    );
  }
  
  Widget _buildPlayersOnIcePanel() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with player count and clear button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text(
                  'PLAYERS ON ICE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedPlayersOnIce.length}/5',
                  style: TextStyle(
                    color: _selectedPlayersOnIce.length == 5 
                        ? Colors.green 
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _clearPlayersOnIce,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          
          // Player selection content
          if (_isLoadingPlayers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'FORWARDS'),
                      Tab(text: 'DEFENSE'),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                  ),
                  SizedBox(
                    height: 200, // Increased height for better visibility
                    child: TabBarView(
                      children: [
                        // Forwards Tab
                        _buildPlayerGrid(_getForwards()),
                        
                        // Defense Tab
                        _buildPlayerGrid(_getDefensemen()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPlayerGrid(List<Player> players) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: players.isEmpty
          ? const Center(child: Text('No players found'))
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final isSelected = _selectedPlayersOnIce.contains(player);
                final isAbsent = _isPlayerAbsent(player);
                
                return InkWell(
                  onTap: isAbsent ? null : () => _togglePlayerOnIce(player),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isAbsent 
                          ? Colors.grey.withOpacity(0.3) 
                          : isSelected 
                              ? Colors.blue.withOpacity(0.2) 
                              : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isAbsent 
                            ? Colors.grey 
                            : isSelected 
                                ? Colors.blue 
                                : Colors.grey.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '#${player.jerseyNumber}',
                            style: TextStyle(
                              fontSize: 20, // Slightly larger font size for better visibility
                              fontWeight: FontWeight.bold,
                              color: isAbsent 
                                  ? Colors.grey 
                                  : isSelected 
                                      ? Colors.blue 
                                      : Colors.black87,
                            ),
                          ),
                        ),
                        if (isAbsent)
                          const Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(
                              Icons.person_off,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
