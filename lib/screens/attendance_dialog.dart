import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:uuid/uuid.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';

/// A dialog that allows tracking player attendance for a specific game.
/// 
/// This dialog displays a grid of players organized by position (forwards and defense)
/// and allows the user to mark players as present or absent. The attendance data
/// is saved locally and can be synced to Google Sheets if the user is signed in.
class AttendanceDialog extends StatefulWidget {
  final String gameId;
  final String teamId;
  final VoidCallback onComplete;

  const AttendanceDialog({
    super.key,
    required this.gameId,
    required this.teamId,
    required this.onComplete,
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

/// State for the AttendanceDialog widget.
class _AttendanceDialogState extends State<AttendanceDialog> {
  List<Player> _yourTeamPlayers = [];
  Set<String> _absentPlayerIds = {}; // Track absent players (deselected)
  bool _isLoadingPlayers = false;
  bool _isSaving = false;
  Game? _currentGame;
  final SheetsService _sheetsService = SheetsService();

  @override
  void initState() {
    super.initState();
    _loadGameInfo();
    _loadPlayers();
    _loadExistingAttendance();
  }

  /// Loads the game information from Hive storage based on the provided gameId.
  Future<void> _loadGameInfo() async {
    final gamesBox = Hive.box<Game>('games');
    setState(() {
      _currentGame = gamesBox.get(widget.gameId);
    });
  }

  /// Loads all players from the local database, filtering for players on your team.
  /// Players are sorted by jersey number.
  Future<void> _loadPlayers() async {
    setState(() {
      _isLoadingPlayers = true;
    });

    try {
      final playersBox = Hive.box<Player>('players');
      // Get all players from your team (including goalies)
      final players = playersBox.values
          .where((p) => p.teamId == widget.teamId)
          .toList();

      // Sort by jersey number
      players.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));

      setState(() {
        _yourTeamPlayers = players;
        _isLoadingPlayers = false;
      });
    } catch (e) {
      print('Error loading players: $e');
      setState(() {
        _isLoadingPlayers = false;
      });
    }
  }

  /// Loads any existing attendance records for this game from the local database.
  /// If records exist, it updates the UI to reflect which players were previously marked as absent.
  Future<void> _loadExistingAttendance() async {
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
      }
    } catch (e) {
      print('Error loading existing attendance: $e');
    }
  }

  /// Toggles a player's attendance status between present and absent.
  /// 
  /// @param player The player whose attendance status is being toggled
  void _togglePlayerAttendance(Player player) {
    setState(() {
      if (_absentPlayerIds.contains(player.id)) {
        _absentPlayerIds.remove(player.id);
      } else {
        _absentPlayerIds.add(player.id);
      }
    });
  }

  /// Saves the current attendance data to the local database and attempts to sync
  /// with Google Sheets if the user is signed in.
  /// 
  /// This method now uses the efficient GameAttendance model:
  /// 1. Creates/updates a single GameAttendance record with only absent player IDs
  /// 2. Schedules background sync to Google Sheets if the user is signed in
  /// 3. Shows confirmation of sync status to the user
  Future<void> _saveAttendance() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
      final uuid = const Uuid();
      final timestamp = DateTime.now();

      // Create or update the single GameAttendance record for this game
      final existingAttendance = attendanceBox.values
          .where((a) => a.gameId == widget.gameId)
          .firstOrNull;

      final gameAttendance = GameAttendance(
        id: existingAttendance?.id ?? uuid.v4(),
        gameId: widget.gameId,
        absentPlayerIds: _absentPlayerIds.toList(),
        timestamp: timestamp,
        teamId: widget.teamId,
        isSynced: false,
      );

      // Delete existing record if it exists
      if (existingAttendance != null) {
        await existingAttendance.delete();
      }

      // Save the new/updated attendance record
      await attendanceBox.put(gameAttendance.id, gameAttendance);

      print('Saved attendance for game ${widget.gameId}: ${_absentPlayerIds.length} absent players');

      // Check if user is signed in for Google Sheets sync
      final isSignedIn = await _sheetsService.isSignedIn();
      
      if (isSignedIn) {
        // Show sync status and attempt sync
        await _showSyncStatusAndSync(gameAttendance);
      } else {
        // Not signed in - show local save confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Attendance saved locally (Google Sheets sync unavailable - not signed in)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
          widget.onComplete();
        }
      }
    } catch (e) {
      print('Error saving attendance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Shows sync status dialog and attempts to sync attendance to Google Sheets
  Future<void> _showSyncStatusAndSync(GameAttendance gameAttendance) async {
    if (!mounted) return;

    // Show sync status dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Syncing to Google Sheets...'),
            ],
          ),
          content: const Text('Please wait while we update your attendance data in Google Sheets.'),
        );
      },
    );

    try {
      // Attempt to sync the attendance record
      print('Attempting to sync attendance to Google Sheets...');
      final syncSuccess = await _sheetsService.syncGameAttendance(gameAttendance);
      
      if (mounted) {
        // Close the sync status dialog
        Navigator.of(context).pop();
        
        if (syncSuccess) {
          // Show success confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Attendance saved and synced to Google Sheets successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          print('Attendance sync successful');
        } else {
          // Show failure message but indicate local save was successful
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠ Attendance saved locally, but Google Sheets sync failed. Will retry automatically.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          print('Attendance sync failed, but saved locally');
        }
        
        // Close the attendance dialog and complete
        Navigator.of(context).pop();
        widget.onComplete();
      }
    } catch (e) {
      print('Error during attendance sync: $e');
      
      if (mounted) {
        // Close the sync status dialog
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠ Attendance saved locally, but sync error occurred: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Close the attendance dialog and complete
        Navigator.of(context).pop();
        widget.onComplete();
      }
    }
  }

  /// Returns a filtered list of players who are forwards (C, LW, RW, F positions).
  List<Player> _getForwards() {
    return _yourTeamPlayers.where((player) =>
        player.position == 'C' ||
        player.position == 'LW' ||
        player.position == 'RW' ||
        player.position == 'F').toList();
  }

  /// Returns a filtered list of players who are defensemen (D, LD, RD positions).
  List<Player> _getDefensemen() {
    return _yourTeamPlayers.where((player) =>
        player.position == 'D' ||
        player.position == 'LD' ||
        player.position == 'RD').toList();
  }

  /// Returns a filtered list of players who are goalies (G position).
  List<Player> _getGoalies() {
    return _yourTeamPlayers.where((player) =>
        player.position == 'G').toList();
  }

  /// Builds a grid of player tiles that can be tapped to toggle attendance status.
  /// 
  /// @param players The list of players to display in the grid
  /// @return A widget representing the grid of player attendance tiles
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
                final isPresent = !_absentPlayerIds.contains(player.id);

                return InkWell(
                  onTap: () => _togglePlayerAttendance(player),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isPresent
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPresent ? Colors.green : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#${player.jerseyNumber}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isPresent ? Colors.green : Colors.red,
                            ),
                          ),
                          if (isPresent)
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.green,
                            )
                          else
                            const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String gameTitle = 'Game Attendance';
    if (_currentGame != null) {
      final dateStr = _currentGame!.date.toLocal().toString().split(' ')[0];
      gameTitle = 'Attendance: $dateStr ${_currentGame!.opponent}';
    }

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              gameTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select players who are ABSENT (tap to toggle)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Player count summary
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Present: ${_yourTeamPlayers.length - _absentPlayerIds.length} / ${_yourTeamPlayers.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Player selection area
            Expanded(
              child: _isLoadingPlayers
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'FORWARDS'),
                              Tab(text: 'DEFENSE'),
                              Tab(text: 'GOALIES'),
                            ],
                            labelColor: Colors.blue,
                            unselectedLabelColor: Colors.grey,
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildPlayerGrid(_getForwards()),
                                _buildPlayerGrid(_getDefensemen()),
                                _buildPlayerGrid(_getGoalies()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Action buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveAttendance,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Attendance'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
