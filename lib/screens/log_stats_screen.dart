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
import 'package:hockey_stats_app/services/memory_cache_service.dart';
import 'package:hockey_stats_app/services/background_sync_service.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/services/voice_command_parser.dart';
import 'package:hockey_stats_app/services/voice_input_service.dart';
import 'package:hockey_stats_app/widgets/voice_verify_sheet.dart';
import 'package:hockey_stats_app/services/line_configuration_service.dart';
import 'package:hockey_stats_app/widgets/share_dialog.dart';
import 'package:hockey_stats_app/services/team_context_service.dart';
import 'package:hockey_stats_app/services/stats_service.dart';
import 'package:hockey_stats_app/widgets/player_selection_widget.dart';
import 'package:hockey_stats_app/services/wakelock_service.dart';
import 'package:hockey_stats_app/screens/app_settings_screen.dart';
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

  // Game situation mode (Even Strength, Power Play, Penalty Kill)
  GoalSituation _currentSituation = GoalSituation.evenStrength;

  // Quick shot logging
  bool _isLogging = false;
  final VoiceInputService _voiceService = VoiceInputService();
  bool _isListening = false;
  String _heardSoFar = '';
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
    
    // Enable wake lock when entering stats screen
    WakelockService.enableWakelockIfAllowed();
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
      // Pre-initialize voice service in background so mic taps are instant
      _voiceService.ensureInitialized();

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
      // First try to load from the new GameAttendance model
      final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
      final existingAttendance = attendanceBox.values
          .where((a) => a.gameId == widget.gameId && a.teamId == widget.teamId)
          .firstOrNull;

      if (existingAttendance != null) {
        setState(() {
          _absentPlayerIds = existingAttendance.absentPlayerIds.toSet();
        });
        print('Loaded attendance from GameAttendance: ${_absentPlayerIds.length} absent players');
        return;
      }

      // Fallback: Load from old GameRoster model for backward compatibility
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
        print('Loaded attendance from GameRoster (legacy): ${_absentPlayerIds.length} absent players');
      } else {
        // No attendance data found, initialize empty set
        setState(() {
          _absentPlayerIds = <String>{};
        });
        print('No attendance data found, initialized empty absent players set');
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

  // Refresh attendance data (can be called when attendance is updated)
  Future<void> _refreshAttendanceData() async {
    print('Refreshing attendance data...');
    await _loadAttendanceData();
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

  /// Manual sync for THIS game only, triggered from the visible
  /// "Sync This Game" menu item. (Replaces the hidden long-press on
  /// the sync badge and the previously unwired _handleSync /
  /// _handleSyncFromSheets methods.)
  Future<void> _syncThisGame() async {
    final result = await _sheetsService.syncPendingEventsForGame(widget.gameId);
    final attendanceResult = await _sheetsService.syncPendingAttendanceForGame(widget.gameId);

    if (!mounted) return;

    final totalSuccess = (result['success'] ?? 0) + (attendanceResult['success'] ?? 0);
    final totalFailed = (result['failed'] ?? 0) + (attendanceResult['failed'] ?? 0);

    String message;
    if (result['pending'] == -1 || attendanceResult['pending'] == -1) {
      message = 'Sync failed: you appear to be offline. Changes are safely stored on this device.';
    } else if (totalFailed > 0) {
      message = 'Synced $totalSuccess items for this game ($totalFailed failed)';
    } else if (totalSuccess > 0) {
      message = 'Successfully synced $totalSuccess items for this game';
      await _refreshScore();
    } else {
      message = 'No items to sync for this game based on your preferences.';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
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
     
     // Only show loading state for explicit refresh operations (like sync)
     // The ValueListenableBuilder will handle automatic updates from local data
     setState(() { _isLoadingScore = true; });
     
     try {
        // Refresh from Google Sheets in background without blocking UI
        print('Refreshing score from Google Sheets in background...');
        
        // Use microtask to avoid blocking the UI thread
        Future.microtask(() async {
          try {
            await _centralizedDataService.calculateCurrentScore(widget.gameId, widget.teamId, forceRefresh: true);
          } catch (e) {
            print('Background score refresh error: $e');
          }
        });
        
        // Clear loading state immediately since local data handles the display
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

  Future<void> _changeGameSituation(GoalSituation newSituation) async {
    // If tapping an already selected situation (other than Even Strength), toggle it off back to Even Strength
    final targetSituation = (_currentSituation == newSituation && newSituation != GoalSituation.evenStrength)
        ? GoalSituation.evenStrength
        : newSituation;

    if (_currentSituation == targetSituation) return;

    // Confirmation dialog before activating Power Play or Penalty Kill mode
    if (targetSituation == GoalSituation.powerPlay) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.bolt, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Start Power Play?'),
            ],
          ),
          content: const Text(
            'This will log an opponent penalty (+1 PP Opportunity) and track all shots as Power Play shots until mode is turned off.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start Power Play'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else if (targetSituation == GoalSituation.shortHanded) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.shield, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Start Penalty Kill?'),
            ],
          ),
          content: const Text(
            'This will log a team penalty (+1 PK Opportunity) and track all shots as Penalty Kill shots until mode is turned off.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start Penalty Kill'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _currentSituation = targetSituation;
    });

    try {
      if (targetSituation == GoalSituation.powerPlay) {
        // Log opponent penalty (gives your team a Power Play opportunity)
        final ppPenaltyEvent = GameEvent(
          id: uuid.v4(),
          gameId: widget.gameId,
          timestamp: DateTime.now(),
          period: _selectedPeriod,
          eventType: 'Penalty',
          team: 'opponent',
          primaryPlayerId: '',
          penaltyType: 'Unspecified',
          penaltyDuration: 2,
          isSynced: false,
        );
        await gameEventsBox.put(ppPenaltyEvent.id, ppPenaltyEvent);
        MemoryCacheService().cacheEvent(ppPenaltyEvent);
        CentralizedDataService().invalidateEvent(widget.gameId);
        BackgroundSyncService().queueEventForSync(ppPenaltyEvent);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ Power Play Mode Active (+1 PP Opportunity)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (targetSituation == GoalSituation.shortHanded) {
        // Log team penalty (puts your team on Penalty Kill opportunity)
        final pkPenaltyEvent = GameEvent(
          id: uuid.v4(),
          gameId: widget.gameId,
          timestamp: DateTime.now(),
          period: _selectedPeriod,
          eventType: 'Penalty',
          team: widget.teamId,
          primaryPlayerId: '',
          penaltyType: 'Unspecified',
          penaltyDuration: 2,
          yourTeamPlayersOnIce: _getPlayersOnIceIds(),
          isSynced: false,
        );
        await gameEventsBox.put(pkPenaltyEvent.id, pkPenaltyEvent);
        MemoryCacheService().cacheEvent(pkPenaltyEvent);
        CentralizedDataService().invalidateEvent(widget.gameId);
        BackgroundSyncService().queueEventForSync(pkPenaltyEvent);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛡️ Penalty Kill Mode Active (+1 PK Opportunity)'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🏒 Returned to Even Strength (5v5)'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error logging situation penalty: $e');
    }
  }



  Future<void> _logQuickShot(String team) async {
    setState(() { _isLogging = true; });

    try {
      GoalSituation shotSituation = _currentSituation;

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
        yourTeamPlayersOnIce: _getPlayersOnIceIds(),
        goalSituation: shotSituation,
        goalieOnIceId: (team == 'opponent')
            ? (_selectedGoalie?.id)
            : 'opponent_g',
      );

      // Save to local storage immediately for instant UI update
      await gameEventsBox.put(newShotEvent.id, newShotEvent);

      if (!mounted) return;

      // Queue for background sync (non-blocking)
      final backgroundSyncService = BackgroundSyncService();
      backgroundSyncService.queueEventForSync(newShotEvent);

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

  // ---------------------------------------------------------------------------
  // Voice control (Phase 1): push-to-talk capture -> parse -> VERIFY -> log.
  // Nothing is logged from recognition alone: every parsed command is shown
  // on the verify card first and only the keeper's Confirm writes an event
  // (Prof's rule). Confirmed commands log through the same GameEvent
  // construction the buttons and log screens use.
  // ---------------------------------------------------------------------------

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      return;
    }
    await _startVoiceListening();
  }

  Future<void> _startVoiceListening() async {
    final available = await _voiceService.ensureInitialized(
      onListeningChanged: (listening) {
        if (mounted && _isListening != listening) {
          setState(() {
            _isListening = listening;
          });
        }
      },
    );
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice recognition is not available on this device.'),
        ),
      );
      return;
    }

    final roster = Hive.box<Player>('players')
        .values
        .where((player) => player.teamId == widget.teamId)
        .toList();
    final parser = VoiceCommandParser(roster);
    bool commandHandled = false;

    setState(() {
      _isListening = true;
      _heardSoFar = '';
    });

    await _voiceService.startListening(
      pauseFor: const Duration(milliseconds: 1200),
      onTranscript: (transcript, isFinal) async {
        if (!mounted || commandHandled) return;
        setState(() {
          _heardSoFar = transcript;
        });

        // Fast path: Attempt early parse on partial transcript for instant response
        final result = parser.parse(transcript);
        if (result.isSuccess) {
          commandHandled = true;
          await _voiceService.stopListening();
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            _processVoiceResult(transcript, result);
          }
          return;
        }

        // On final result, if early parse didn't match, handle result/rejection
        if (isFinal && !commandHandled) {
          commandHandled = true;
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            _processVoiceResult(transcript, result);
          }
        }
      },
    );
  }

  Future<void> _processVoiceResult(String transcript, VoiceParseResult result) async {
    if (!mounted) return;

    if (!result.isSuccess) {
      final retry = await showVoiceRejectionSheet(
        context,
        reason: result.rejectionReason!,
        heardText: transcript,
      );
      if (retry && mounted) {
        await _startVoiceListening();
      }
      return;
    }

    final command = result.command!;
    if (command.kind == VoiceCommandKind.undo) {
      await _verifyAndUndo(transcript);
      return;
    }

    final canEdit = command.kind == VoiceCommandKind.playerShot ||
        command.kind == VoiceCommandKind.goal ||
        command.kind == VoiceCommandKind.penalty;
    final decision = await showVoiceVerifySheet(
      context,
      description: command.describe(),
      heardText: transcript,
      showEdit: canEdit,
    );
    if (!mounted) return;
    switch (decision) {
      case VoiceVerifyDecision.confirm:
        await _executeVoiceCommand(command);
        break;
      case VoiceVerifyDecision.edit:
        await _editVoiceCommand(command);
        break;
      case VoiceVerifyDecision.discard:
        break;
    }
  }

  Future<void> _executeVoiceCommand(VoiceCommand command) async {
    switch (command.kind) {
      case VoiceCommandKind.teamShot:
        await _logQuickShot(widget.teamId);
        break;
      case VoiceCommandKind.opponentShot:
        await _logQuickShot('opponent');
        break;
      case VoiceCommandKind.playerShot:
        await _logVoicePlayerEvent(command, isGoal: false);
        break;
      case VoiceCommandKind.goal:
        await _logVoicePlayerEvent(command, isGoal: true);
        setState(() {
          _selectedGoalScorer = null;
          _selectedAssist = null;
          _selectedAssist2 = null;
        });
        break;
      case VoiceCommandKind.penalty:
        final saved = await _logVoicePenalty(command);
        if (saved) {
          // Mirror the Log Penalty button: our penalty puts us short handed.
          setState(() {
            _currentSituation = GoalSituation.shortHanded;
          });
        }
        break;
      case VoiceCommandKind.undo:
        break; // Handled by _verifyAndUndo.
    }
    await _refreshScore();
    _refreshAttendanceData();
    if (mounted) {
      setState(() {});
    }
  }

  /// Logs a shot or goal for a spoken player, mirroring the event the
  /// Log Shot / Log Goal screens construct (same fields, same sync queue).
  Future<void> _logVoicePlayerEvent(VoiceCommand command,
      {required bool isGoal}) async {
    setState(() {
      _isLogging = true;
    });
    try {
      final event = GameEvent(
        id: uuid.v4(),
        gameId: widget.gameId,
        timestamp: DateTime.now(),
        period: _selectedPeriod,
        eventType: 'Shot',
        team: widget.teamId,
        primaryPlayerId: command.player!.id,
        assistPlayer1Id: isGoal ? command.assist1?.id : null,
        assistPlayer2Id: isGoal ? command.assist2?.id : null,
        isGoal: isGoal,
        isSynced: false,
        yourTeamPlayersOnIce: _getPlayersOnIceIds(),
        goalSituation:
            isGoal ? (command.situation ?? _currentSituation) : _currentSituation,
        goalieOnIceId: 'opponent_g',
      );
      await gameEventsBox.put(event.id, event);
      BackgroundSyncService().queueEventForSync(event);
    } catch (e) {
      print('Error in _logVoicePlayerEvent: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging event: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }

  /// Logs a spoken penalty, mirroring Log Penalty's save (Hive put, cache
  /// updates, sync queue). Returns whether the event was written.
  Future<bool> _logVoicePenalty(VoiceCommand command) async {
    try {
      final event = GameEvent(
        id: uuid.v4(),
        gameId: widget.gameId,
        timestamp: DateTime.now(),
        period: _selectedPeriod,
        eventType: 'Penalty',
        team: widget.teamId,
        primaryPlayerId: command.player!.id,
        penaltyType: command.penaltyType,
        penaltyDuration: command.penaltyMinutes,
        yourTeamPlayersOnIce:
            LineConfigurationService.instance.getActiveOnIcePlayerIds(),
        isSynced: false,
      );
      await gameEventsBox.put(event.id, event);
      MemoryCacheService().cacheEvent(event);
      CentralizedDataService().invalidateEvent(widget.gameId);
      CentralizedDataService().clearCache();
      BackgroundSyncService().queueEventForSync(event);
      return true;
    } catch (e) {
      print('Error in _logVoicePenalty: $e');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging penalty: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    }
  }

  /// Opens the matching log screen pre-filled with the parsed command, so
  /// the keeper can correct it by hand instead of confirming or discarding.
  Future<void> _editVoiceCommand(VoiceCommand command) async {
    switch (command.kind) {
      case VoiceCommandKind.playerShot:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LogShotScreen(
              gameId: widget.gameId,
              period: _selectedPeriod,
              teamId: widget.teamId,
              playersOnIce: _selectedPlayersOnIce,
              initialShooter: command.player,
            ),
          ),
        );
        break;
      case VoiceCommandKind.goal:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LogGoalScreen(
              gameId: widget.gameId,
              period: _selectedPeriod,
              teamId: widget.teamId,
              playersOnIce: _selectedPlayersOnIce,
              goalScorer: command.player,
              assist1: command.assist1,
              assist2: command.assist2,
              selectedGoalie: _selectedGoalie,
              initialSituation: command.situation ?? _currentSituation,
            ),
          ),
        );
        break;
      case VoiceCommandKind.penalty:
        final value = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LogPenaltyScreen(
              gameId: widget.gameId,
              period: _selectedPeriod,
              teamId: widget.teamId,
              initialPlayer: command.player,
              initialPenaltyType: command.penaltyType,
              initialDuration: command.penaltyMinutes,
            ),
          ),
        );
        final bool penaltySaved = value is Map && value['saved'] == true;
        if (penaltySaved && mounted) {
          setState(() {
            _currentSituation = GoalSituation.shortHanded;
          });
        }
        break;
      case VoiceCommandKind.teamShot:
      case VoiceCommandKind.opponentShot:
      case VoiceCommandKind.undo:
        break; // These commands have no pre-filled edit screen.
    }
    await _refreshScore();
    _refreshAttendanceData();
    if (mounted) {
      setState(() {});
    }
  }

  /// Voice Undo: the verify card names the exact event that would be
  /// deleted; only a Confirm deletes it (locally and from the Sheet, the
  /// same order Edit Logged Shots uses).
  Future<void> _verifyAndUndo(String heardText) async {
    final events = gameEventsBox.values
        .where((event) => event.gameId == widget.gameId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to undo — no events logged for this game yet.'),
        ),
      );
      return;
    }
    final last = events.last;
    final decision = await showVoiceVerifySheet(
      context,
      description: 'Undo — delete: ${_describeEvent(last)}',
      heardText: heardText,
    );
    if (decision != VoiceVerifyDecision.confirm || !mounted) return;

    if (last.isSynced) {
      final deletedFromSheet =
          await _sheetsService.deleteEventFromSheet(last.id);
      if (!deletedFromSheet) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not delete that event from Google Sheets — it was not removed.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }
    await last.delete();
    CentralizedDataService().invalidateEvent(widget.gameId);
    CentralizedDataService().clearCache();
    await _refreshScore();
    _refreshAttendanceData();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Last event deleted.')),
      );
    }
  }

  String _describeEvent(GameEvent event) {
    final jersey = _jerseyForPlayerId(event.primaryPlayerId);
    final who = jersey != null ? ' #$jersey' : '';
    switch (event.eventType) {
      case 'Shot':
        if (event.isGoal == true) {
          return 'Goal by$who · Period ${event.period}';
        }
        if (event.team == 'opponent') {
          return 'Opponent shot · Period ${event.period}';
        }
        return jersey != null
            ? 'Shot by$who · Period ${event.period}'
            : 'Team shot · Period ${event.period}';
      case 'Penalty':
        return 'Penalty${event.penaltyType != null ? ' (${event.penaltyType})' : ''} on$who · Period ${event.period}';
      default:
        return '${event.eventType} · Period ${event.period}';
    }
  }

  String? _jerseyForPlayerId(String playerId) {
    if (playerId.isEmpty) return null;
    for (final player in Hive.box<Player>('players').values) {
      if (player.id == playerId) {
        return '${player.jerseyNumber}';
      }
    }
    return null;
  }

  List<String> _getPlayersOnIceIds() {
    return _selectedPlayersOnIce.map((player) => player.id).toList();
  }

  @override
  void dispose() {
    // Disable wake lock when leaving stats screen
    WakelockService.disableWakelock();
    _voiceService.cancel();
    super.dispose();
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
        titleSpacing: 4.0,
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
                  return PopupMenuButton<String>(
                    icon: Badge(
                      label: Text(count.toString()),
                      isLabelVisible: count > 0,
                      child: const Icon(Icons.cloud_sync),
                    ),
                    tooltip: count > 0
                        ? '$count unsynced item(s) - tap for sync options'
                        : 'Sync options',
                    onSelected: (value) {
                      if (value == 'sync_game') {
                        _syncThisGame();
                      } else if (value == 'view_unsynced') {
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
                      const PopupMenuItem(
                        value: 'sync_game',
                        child: Row(
                          children: [
                            Icon(Icons.cloud_sync, size: 20),
                            SizedBox(width: 8),
                            Text('Sync This Game'),
                          ],
                        ),
                      ),
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
                    print('Returned from EditShotListScreen, refreshing score and attendance...');
                    _refreshScore().then((_) {
                      print('Score refresh complete');
                    });
                    _refreshAttendanceData();
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
              padding: const EdgeInsets.only(right: 4.0),
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
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'App Settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
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
                const SizedBox(height: 12),

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
                  gameId: widget.gameId,
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
                  initialIsPowerPlay: _currentSituation == GoalSituation.powerPlay,
                  onPowerPlayChanged: (val) {
                    _changeGameSituation(val ? GoalSituation.powerPlay : GoalSituation.evenStrength);
                  },
                  initialIsPenaltyKill: _currentSituation == GoalSituation.shortHanded,
                  onPenaltyKillChanged: (val) {
                    _changeGameSituation(val ? GoalSituation.shortHanded : GoalSituation.evenStrength);
                  },
                ),

                const SizedBox(height: 16),

                // Streamlined shot and goal logging controls
                Column(
                  children: [
                    // Voice command button: tap to talk; the parsed
                    // command is always verified before it is logged.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLogging ? null : _toggleVoiceInput,
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                        label: Text(_isListening
                            ? (_heardSoFar.isEmpty
                                ? 'Listening… tap to stop'
                                : 'Heard: $_heardSoFar')
                            : 'Voice Command'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          elevation: 0,
                          backgroundColor: _isListening ? Colors.red.shade700 : const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                              selectedGoalie: _selectedGoalie,
                              initialSituation: _currentSituation,
                            ),
                          ),
                        ).then((value) {
                            print('Returned from LogGoalScreen, refreshing score and attendance...');
                            _refreshScore().then((_) {
                              print('Score refresh complete');
                              setState(() {
                                // Situation mode intentionally PERSISTS after a goal:
                                // a short-handed goal never ends a penalty kill, and a
                                // power-play goal may not end a 5-on-3. The keeper ends
                                // the mode with the PP/PK toggle. (The old auto-reset
                                // silently stamped later events Even Strength.)
                                if (value != null && value is int) {
                                  _selectedPeriod = value;
                                }
                                // Clear goal scorer and assist selections after logging
                                _selectedGoalScorer = null;
                                _selectedAssist = null;
                                _selectedAssist2 = null;
                              });
                            });
                            _refreshAttendanceData();
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
                            print('Returned from LogPenaltyScreen, refreshing score and attendance...');
                            // LogPenaltyScreen returns {'period': n, 'saved': true} only when a
                            // penalty was actually logged; backing out returns the period int
                            // (or null) and must NOT change the game situation.
                            final bool penaltySaved = value is Map && value['saved'] == true;
                            final int? returnedPeriod = value is Map
                                ? (value['period'] is int ? value['period'] as int : null)
                                : (value is int ? value : null);
                            _refreshScore().then((_) {
                              print('Score refresh complete');
                              setState(() {
                                if (penaltySaved) {
                                  _currentSituation = GoalSituation.shortHanded;
                                }
                                if (returnedPeriod != null) {
                                  _selectedPeriod = returnedPeriod;
                                }
                                // Clear goal scorer and assist selections after logging penalty
                                _selectedGoalScorer = null;
                                _selectedAssist = null;
                                _selectedAssist2 = null;
                              });
                            });
                            _refreshAttendanceData();
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
                          
                          ValueListenableBuilder(
                            valueListenable: Hive.box<GameEvent>('gameEvents').listenable(),
                            builder: (context, Box<GameEvent> box, _) {
                              if (_isLoadingScore) {
                                return const Center(
                                  child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 3))
                                );
                              }
                              
                              // Calculate score from local data for instant updates
                              final gameEvents = box.values.where((event) => event.gameId == widget.gameId).toList();
                              final goalEvents = gameEvents.where((event) => 
                                event.eventType == 'Shot' && event.isGoal == true
                              ).toList();
                              
                              final yourTeamScore = goalEvents.where((event) => event.team == widget.teamId).length;
                              final opponentScore = goalEvents.where((event) => event.team == 'opponent').length;
                              
                              return Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$yourTeamScore',
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
                                      '$opponentScore',
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
                  onTap: () => _togglePlayerOnIce(player),
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
