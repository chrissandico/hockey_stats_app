import 'package:flutter/material.dart';
import 'package:hockey_stats_app/screens/log_goal_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:hockey_stats_app/screens/edit_shot_list_screen.dart';
import 'package:hockey_stats_app/screens/unsynced_events_screen.dart';
import 'package:hockey_stats_app/screens/sync_settings_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:hockey_stats_app/services/centralized_data_service.dart';
import 'package:hockey_stats_app/widgets/share_dialog.dart';
import 'package:hockey_stats_app/services/team_context_service.dart';
import 'package:hockey_stats_app/widgets/player_selection_widget.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

// Removed - now using CentralizedDataService for score calculation

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
  final TeamContextService _teamContextService = TeamContextService();
  final CentralizedDataService _centralizedDataService = CentralizedDataService();
  String? _currentUser; // Changed from GoogleSignInAccount? to String?
  bool _isSigningIn = false;
  bool _isLoadingInitialData = true;
  String _currentTeamName = 'Your Team'; // Dynamic team name
  
  // Players on ice tracking
  List<Player> _yourTeamPlayers = [];
  List<Player> _goalies = [];
  List<Player> _selectedPlayersOnIce = [];
  Player? _selectedGoalScorer;
  Player? _selectedAssist;
  Player? _selectedAssist2;
  Player? _selectedGoalie;
  bool _isLoadingPlayers = false;
  
  // Attendance tracking
  Set<String> _absentPlayerIds = {}; // Track absent players
  bool _isLoadingAttendance = false;

  // Quick shot logging
  bool _isLogging = false;
  final uuid = Uuid();
  late Box<GameEvent> gameEventsBox;
  
  // Sync status tracking
  String? _syncStatus;
  bool _isSyncingInBackground = false;

  @override
  void initState() {
    super.initState();
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    _initializeScreenAsync();
  }

  /// Initialize the screen with optimized async loading
  Future<void> _initializeScreenAsync() async {
    // Load essential data first (blocking - needed for UI)
    await _loadInitialData();
    
    // Load other data in background (non-blocking)
    _loadBackgroundData();
  }
  
  /// Load non-essential data in background to avoid blocking UI
  void _loadBackgroundData() {
    // Use microtasks to ensure UI renders first
    Future.microtask(() async {
      // Load data in parallel but don't block UI
      final futures = [
        _checkSignInStatus(),
        _loadPlayers(),
        _loadCurrentTeamName(),
        _loadAttendanceData(),
      ];
      
      // Process results as they complete
      for (final future in futures) {
        future.catchError((error) {
          print('Background data loading error: $error');
          return null;
        });
      }
      
      // Wait for all to complete
      await Future.wait(futures, eagerError: false);
      
      print('Background data loading completed');
    });
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
      
      // Load goalies separately
      _goalies = playersBox.values
          .where((p) => p.teamId == widget.teamId && p.position == 'G')
          .toList();
      _goalies.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
      
      // Set default goalie if available and none selected
      if (_goalies.isNotEmpty && _selectedGoalie == null) {
        _selectedGoalie = _goalies.first;
      }
      
      // Filter out goalies (players with position "G") for skaters
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
  
  // Load the current team name
  Future<void> _loadCurrentTeamName() async {
    try {
      final teamName = await _teamContextService.getCurrentTeamName();
      if (mounted) {
        setState(() {
          _currentTeamName = teamName;
        });
      }
    } catch (e) {
      print('Error loading current team name: $e');
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
  
  List<Player> _getAllSkaters() {
    // Get forwards and sort by jersey number
    final forwards = _yourTeamPlayers.where((player) => 
      player.position == 'C' || 
      player.position == 'LW' || 
      player.position == 'RW' ||
      player.position == 'F'
    ).toList();
    forwards.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Get defensemen and sort by jersey number
    final defensemen = _yourTeamPlayers.where((player) => 
      player.position == 'D' || 
      player.position == 'LD' || 
      player.position == 'RD'
    ).toList();
    defensemen.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Combine with forwards first, then defensemen
    return [...forwards, ...defensemen];
  }
  
  bool _isForward(Player player) {
    return player.position == 'C' || 
           player.position == 'LW' || 
           player.position == 'RW' ||
           player.position == 'F';
  }
  
  bool _isDefenseman(Player player) {
    return player.position == 'D' || 
           player.position == 'LD' || 
           player.position == 'RD';
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
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPeriodButton(1),
          _buildPeriodButton(2),
          _buildPeriodButton(3),
          _buildPeriodButton(4, label: 'OT'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(int period, {String? label}) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedPeriod = period;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
            foregroundColor: isSelected ? Colors.white : null,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            label ?? 'P$period',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshScore() async {
     if (!mounted) return;
     setState(() { _isLoadingScore = true; });
     try {
        // Force refresh from Google Sheets to get the latest data
        print('Refreshing score from Google Sheets...');
        await _centralizedDataService.calculateCurrentScore(widget.gameId, widget.teamId, forceRefresh: true);
        
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

  Future<void> _logQuickShot(String team) async {
    setState(() { _isLogging = true; });

    try {
      final newShotEvent = GameEvent(
        id: uuid.v4(),
        gameId: widget.gameId,
        timestamp: DateTime.now(),
        period: _selectedPeriod,
        eventType: 'Shot',
        team: team,
        primaryPlayerId: '', // No player details for quick shots
        assistPlayer1Id: null,
        assistPlayer2Id: null,
        isGoal: false,
        isSynced: false,
        yourTeamPlayersOnIce: team == 'opponent' ? null : _getPlayersOnIceIds(),
        goalSituation: null,
        goalieOnIceId: (team == 'opponent' && _selectedGoalie != null) ? _selectedGoalie!.id : null,
      );

      await gameEventsBox.put(newShotEvent.id, newShotEvent);

      // Attempt to sync
      bool syncSuccess = false;
      String syncError = '';
      try {
        syncSuccess = await _sheetsService.syncGameEvent(newShotEvent);
        if (!syncSuccess) {
          syncError = "Sync failed - will retry when online.";
        }
      } catch (error) {
        syncError = error.toString();
        print("Error during sync for quick shot: $error");
      }

      if (!mounted) return;

      String teamDisplayName = team == widget.teamId ? _currentTeamName : 'Opponent';
      String message;
      Color? backgroundColor;
      Widget? icon;
      
      if (syncSuccess) {
        message = 'Shot logged for $teamDisplayName and synced.';
      } else {
        // Check if the error is due to being offline
        if (syncError.toLowerCase().contains('offline') || 
            syncError.toLowerCase().contains('connection') ||
            syncError.toLowerCase().contains('network') ||
            syncError.toLowerCase().contains('retry when online')) {
          message = 'Shot logged successfully! Your changes will automatically sync when your device is back online.';
          backgroundColor = Colors.blue;
          icon = const Icon(Icons.info_outline, color: Colors.white, size: 20);
        } else {
          message = 'Shot logged for $teamDisplayName locally - $syncError';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: syncSuccess ? 2 : 4),
        ),
      );

      await _refreshScore();

    } catch (e) {
      print('Error in _logQuickShot: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging shot: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() { _isLogging = false; });
      }
    }
  }

  List<String> _getPlayersOnIceIds() {
    return _selectedPlayersOnIce.map((player) => player.id).toList();
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
            // Sync badge first to ensure it has enough space
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: StreamBuilder<int>(
                stream: Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
                  // Get user preferences to filter events
                  final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
                  final prefs = prefsBox.get('user_prefs') ?? SyncPreferences();
                  
                  // Count unsynced events that match preferences
                  final gameEventsBox = Hive.box<GameEvent>('gameEvents');
                  final unsyncedEvents = gameEventsBox.values
                      .where((event) => !event.isSynced && prefs.shouldSyncEvent(event))
                      .length;
                  
                  // Count unsynced attendance if enabled
                  int unsyncedAttendance = 0;
                  if (prefs.shouldSyncAttendance()) {
                    final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
                    unsyncedAttendance = attendanceBox.values
                        .where((attendance) => !attendance.isSynced)
                        .length;
                  }
                  
                  return unsyncedEvents + unsyncedAttendance;
                }),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return GestureDetector(
                    onLongPress: () async {
                      // Long press triggers sync
                      final result = await _sheetsService.syncPendingEventsInBackground();
                      final attendanceResult = await _sheetsService.syncPendingAttendanceInBackground();
                      
                      final totalSuccess = (result['success'] ?? 0) + (attendanceResult['success'] ?? 0);
                      final totalFailed = (result['failed'] ?? 0) + (attendanceResult['failed'] ?? 0);
                      
                      if (!mounted) return;
                      
                      String message;
                      SnackBarAction? action;
                      
                      if (result['pending'] == -1 || attendanceResult['pending'] == -1) {
                        message = 'Your device appears to be offline. All changes are safely stored and will automatically sync when your connection is restored.';
                      } else if (totalFailed > 0) {
                        message = 'Synced $totalSuccess items ($totalFailed failed)';
                        action = SnackBarAction(
                          label: 'Retry',
                          onPressed: () async {
                            await _sheetsService.syncPendingEventsInBackground();
                            await _sheetsService.syncPendingAttendanceInBackground();
                          },
                        );
                      } else if (totalSuccess > 0) {
                        message = 'Successfully synced $totalSuccess items';
                        await _refreshScore();
                      } else {
                        message = 'No items to sync based on your preferences.';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              if (result['pending'] == -1 || attendanceResult['pending'] == -1) 
                                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                              if (result['pending'] == -1 || attendanceResult['pending'] == -1) 
                                const SizedBox(width: 8),
                              Expanded(child: Text(message)),
                            ],
                          ),
                          backgroundColor: (result['pending'] == -1 || attendanceResult['pending'] == -1)
                              ? Colors.blue 
                              : null,
                          action: action,
                          duration: Duration(seconds: (result['pending'] == -1 || attendanceResult['pending'] == -1) ? 4 : 3),
                        ),
                      );
                    },
                    child: PopupMenuButton<String>(
                      icon: Badge(
                        label: Text(count.toString()),
                        isLabelVisible: count > 0,
                        child: const Icon(Icons.cloud_sync),
                      ),
                      tooltip: count > 0 
                          ? 'View $count unsynced events\nLong press to sync'
                          : 'All events synced',
                      onSelected: (value) {
                        if (value == 'view_unsynced') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UnsyncedEventsScreen(gameId: widget.gameId),
                            ),
                          );
                        } else if (value == 'sync_settings') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SyncSettingsScreen(),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view_unsynced',
                          child: Row(
                            children: [
                              const Icon(Icons.list, size: 20),
                              const SizedBox(width: 8),
                              Text('View Unsynced Events ($count)'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'sync_settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings, size: 20),
                              SizedBox(width: 8),
                              Text('Sync Settings'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: IconButton(
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
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share Game Stats',
                onPressed: () async {
                  if (_currentGame == null) return;

                  final playersBox = Hive.box<Player>('players');
                  final players = playersBox.values.where((player) => player.teamId == widget.teamId).toList();

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
                        game: _currentGame!,
                        teamId: widget.teamId,
                      ),
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.bar_chart),
                tooltip: 'View Stats',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ViewStatsScreen(gameId: widget.gameId, teamId: widget.teamId)),
                  );
                },
              ),
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
                
                // Use shared player selection widget
                if (_isLoadingPlayers)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                PlayerSelectionWidget(
                  players: _yourTeamPlayers,
                  goalies: _goalies,
                  absentPlayerIds: _absentPlayerIds,
                  selectedPlayersOnIce: _selectedPlayersOnIce,
                  selectedGoalScorer: _selectedGoalScorer,
                  selectedAssist1: _selectedAssist,
                  selectedAssist2: _selectedAssist2,
                  selectedGoalie: _selectedGoalie,
                  onPlayersOnIceChanged: (players) {
                    setState(() {
                      _selectedPlayersOnIce = players;
                    });
                  },
                  onGoalScorerChanged: (player) {
                    setState(() {
                      _selectedGoalScorer = player;
                    });
                  },
                  onAssist1Changed: (player) {
                    setState(() {
                      _selectedAssist = player;
                    });
                  },
                  onAssist2Changed: (player) {
                    setState(() {
                      _selectedAssist2 = player;
                    });
                  },
                  onGoalieChanged: (player) {
                    setState(() {
                      _selectedGoalie = player;
                    });
                  },
                ),

                const SizedBox(height: 24),

                // NEW: 5-button layout for streamlined shot logging
                Column(
                  children: [
                    // Top row: Team shot buttons with SOG counts
                    ValueListenableBuilder(
                      valueListenable: Hive.box<GameEvent>('gameEvents').listenable(),
                      builder: (context, Box<GameEvent> box, _) {
                        final gameEvents = box.values.where((event) => event.gameId == widget.gameId).toList();
                        
                        // Filter shot events
                        final shotEvents = gameEvents.where((event) => event.eventType == 'Shot').toList();
                        
                        // Calculate shots on goal (includes goals)
                        final yourTeamShots = shotEvents.where((event) => event.team == widget.teamId).length;
                        final opponentShots = shotEvents.where((event) => event.team == 'opponent').length;

                        return Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: ElevatedButton(
                                  onPressed: _isLogging ? null : () => _logQuickShot(widget.teamId),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    backgroundColor: const Color(0xFF1976D2), // Material Blue 700
                                    foregroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sports_hockey, size: 28.0, color: Colors.white),
                                      const SizedBox(height: 6.0),
                                      Text(
                                        '$_currentTeamName\nShot',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4.0),
                                      Text(
                                        'SOG: $yourTeamShots',
                                        style: const TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: ElevatedButton(
                                  onPressed: _isLogging ? null : () => _logQuickShot('opponent'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    backgroundColor: const Color(0xFFD32F2F), // Material Red 700
                                    foregroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sports_hockey, size: 28.0, color: Colors.white),
                                      const SizedBox(height: 6.0),
                                      const Text(
                                        'Opponent\nShot',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4.0),
                                      Text(
                                        'SOG: $opponentShots',
                                        style: const TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Middle row: Goal button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LogGoalScreen(
                              gameId: widget.gameId,
                              period: _selectedPeriod,
                              teamId: widget.teamId,
                              playersOnIce: _selectedPlayersOnIce,
                              goalScorer: _selectedGoalScorer,
                              assist1: _selectedAssist,
                              assist2: _selectedAssist2,
                            ),
                          ),
                        ).then((value) {
                            print('Returned from LogGoalScreen, refreshing score...');
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
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 22.0, horizontal: 20.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          backgroundColor: const Color(0xFF388E3C), // Material Green 700
                          foregroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sports_score, size: 32.0, color: Colors.white),
                            const SizedBox(width: 12.0),
                            const Text(
                              'Log Goal',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Bottom row: Penalty button (smaller)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
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
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 18.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          backgroundColor: const Color(0xFFFF8F00), // Material Orange 700
                          foregroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sports, size: 24.0, color: Colors.white),
                            const SizedBox(width: 8.0),
                            const Text(
                              'Log Penalty',
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                              _currentTeamName,
                              _currentGame!.opponent,
                              size: 50.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          FutureBuilder<Map<String, int>>(
                            future: _centralizedDataService.calculateCurrentScore(widget.gameId, widget.teamId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting || _isLoadingScore) {
                                return const Center(
                                  child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 3))
                                );
                              }
                              
                              final score = snapshot.data ?? {'Your Team': 0, 'Opponent': 0};
                              
                              return Center(
                                child: Row(
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

                // Sync status indicator
                if (_syncStatus != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: _isSyncingInBackground 
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: _isSyncingInBackground 
                            ? Colors.blue.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_isSyncingInBackground)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _syncStatus!,
                            style: TextStyle(
                              fontSize: 14,
                              color: _isSyncingInBackground 
                                  ? Colors.blue[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ),
                        if (!_isSyncingInBackground)
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setState(() {
                                _syncStatus = null;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ],
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
            SizedBox(
              height: 250, // Increased height to accommodate all players
              child: _buildPlayerGrid(_getAllSkaters()),
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
                final isForward = _isForward(player);
                final positionLabel = isForward ? 'F' : 'D';
                
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
                              fontSize: 18, // Slightly smaller to make room for position badge
                              fontWeight: FontWeight.bold,
                              color: isAbsent 
                                  ? Colors.grey 
                                  : isSelected 
                                      ? Colors.blue 
                                      : Colors.black87,
                            ),
                          ),
                        ),
                        // Position indicator badge
                        Positioned(
                          top: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isForward 
                                  ? Colors.orange.withOpacity(0.8) 
                                  : Colors.green.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              positionLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
