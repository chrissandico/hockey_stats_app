import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:hockey_stats_app/services/team_context_service.dart';
import 'package:hockey_stats_app/widgets/goal_situation_dialog.dart';
import 'package:hockey_stats_app/widgets/player_selection_widget.dart';

class LogShotScreen extends StatefulWidget {
  final String gameId;
  final int period;
  final String teamId;
  final String? eventIdToEdit;
  final List<Player>? playersOnIce;

  const LogShotScreen({
    super.key, 
    required this.gameId,
    required this.period,
    required this.teamId,
    this.eventIdToEdit,
    this.playersOnIce,
  });

  @override
  _LogShotScreenState createState() => _LogShotScreenState();
}

class _LogShotScreenState extends State<LogShotScreen> {
  // State variables to hold the input values
  late int _selectedPeriod;
  bool _isGoal = false;
  String _selectedTeam = '';
  Player? _selectedShooter; // Represents the Goal Scorer
  Player? _selectedAssist1;
  Player? _selectedAssist2;
  List<Player> _selectedYourTeamPlayersOnIce = [];
  
  // Goal situation tracking
  bool _isPowerPlay = false;
  bool _isPenaltyKill = false;
  
  // Attendance tracking
  Set<String> _absentPlayerIds = {}; // Track absent players
  bool _isLoadingAttendance = false;
  
  // Tab controller for player selection
  late TabController _tabController;

  // Hive Box for GameEvents
  late Box<GameEvent> gameEventsBox;
  late SheetsService _sheetsService;

  // Uuid generator for unique IDs
  final uuid = Uuid();

  // Filtered player lists based on selected team
  List<Player> _playersForTeam = [];
  List<Player> _yourTeamPlayers = [];
  List<Player> _goalies = [];
  Player? _selectedGoalie;

  // Flag to indicate if we're in edit mode
  bool _isEditMode = false;
  // Store the event being edited
  GameEvent? _eventBeingEdited;
  // State variable for loading indicator
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.period;
    _selectedTeam = widget.teamId; // Initialize with the actual team ID
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    _sheetsService = SheetsService();
    _loadPlayers();
    _removeOpponentPlayers();
    _filterPlayersByTeam();
    _loadAttendanceData();
    
    // Initialize players on ice from the passed parameter if available
    if (widget.playersOnIce != null && widget.playersOnIce!.isNotEmpty) {
      _selectedYourTeamPlayersOnIce = List.from(widget.playersOnIce!);
    }
    
    if (widget.eventIdToEdit != null) {
      _loadEventForEditing();
    } else {
      _selectedShooter = null;
      _selectedAssist1 = null;
      _selectedAssist2 = null;
    }
  }

  void _loadPlayers() {
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
    final allSkaters = playersBox.values
        .where((p) => p.teamId == widget.teamId && p.position != 'G')
        .toList();
    
    // Get forwards and sort by jersey number
    final forwards = allSkaters.where((player) => 
      player.position == 'C' || 
      player.position == 'LW' || 
      player.position == 'RW' ||
      player.position == 'F'
    ).toList();
    forwards.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Get defensemen and sort by jersey number
    final defensemen = allSkaters.where((player) => 
      player.position == 'D' || 
      player.position == 'LD' || 
      player.position == 'RD'
    ).toList();
    defensemen.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Combine with forwards first, then defensemen
    _yourTeamPlayers = [...forwards, ...defensemen];
  }
  
  // Load attendance data for the current game
  Future<void> _loadAttendanceData() async {
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
      setState(() {
        _isLoadingAttendance = false;
      });
    }
  }
  
  // Check if a player is absent
  bool _isPlayerAbsent(Player player) {
    return _absentPlayerIds.contains(player.id);
  }
  
  // Helper methods for position detection
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

  void _filterPlayersByTeam() {
    setState(() {
      final playersBox = Hive.box<Player>('players');
      if (_selectedTeam == widget.teamId) {
        _playersForTeam = playersBox.values.where((p) => p.teamId == widget.teamId).toList();
        // Sort players by jersey number
        _playersForTeam.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
      } else {
        _playersForTeam.clear();
        _selectedShooter = null;
      }
    });
  }

  void _loadEventForEditing() {
    try {
      _eventBeingEdited = gameEventsBox.get(widget.eventIdToEdit);
      
      if (_eventBeingEdited != null) {
        _isEditMode = true;
        
        setState(() {
          _selectedPeriod = _eventBeingEdited!.period;
          _isGoal = _eventBeingEdited!.isGoal ?? false;
          _selectedTeam = _eventBeingEdited!.team;
          
          if (_selectedTeam == widget.teamId && _eventBeingEdited!.primaryPlayerId.isNotEmpty) {
            try {
              _selectedShooter = _yourTeamPlayers.firstWhere(
                (player) => player.id == _eventBeingEdited!.primaryPlayerId
              );
            } catch (e) {
              print('Shooter not found: ${_eventBeingEdited!.primaryPlayerId}');
              _selectedShooter = null;
            }
          }
          
          if (_isGoal && _eventBeingEdited!.assistPlayer1Id != null) {
            try {
              _selectedAssist1 = _yourTeamPlayers.firstWhere(
                (player) => player.id == _eventBeingEdited!.assistPlayer1Id
              );
            } catch (e) {
              print('Assist player not found: ${_eventBeingEdited!.assistPlayer1Id}');
              _selectedAssist1 = null;
            }
          }
          
          if (_isGoal && _eventBeingEdited!.yourTeamPlayersOnIce != null) {
            _selectedYourTeamPlayersOnIce = _yourTeamPlayers.where(
              (player) => _eventBeingEdited!.yourTeamPlayersOnIce!.contains(player.id)
            ).toList();
          }
          
          // Load goal situation state from existing event
          if (_isGoal && _eventBeingEdited!.goalSituation != null) {
            switch (_eventBeingEdited!.goalSituation!) {
              case GoalSituation.powerPlay:
                _isPowerPlay = true;
                _isPenaltyKill = false;
                break;
              case GoalSituation.shortHanded:
                _isPowerPlay = false;
                _isPenaltyKill = true;
                break;
              case GoalSituation.evenStrength:
                _isPowerPlay = false;
                _isPenaltyKill = false;
                break;
            }
          }
        });
      }
    } catch (e) {
      print('Error loading event for editing: $e');
      _isEditMode = false;
    }
  }

  Future<void> _logShot() async {
    if (_selectedTeam == widget.teamId && _selectedShooter == null && _isGoal == true) {
      if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a goal scorer.')),
      );
      return;
    }
    
    // Validate player count for goals (3-6 players allowed)
    if (_isGoal && (_selectedYourTeamPlayersOnIce.length < 3 || _selectedYourTeamPlayersOnIce.length > 6)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must select between 3-6 players on ice for a goal.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check for special situations and show confirmation dialog
    if (_isGoal && _selectedYourTeamPlayersOnIce.length < 5) {
      final detectedSituation = _detectGoalSituation();
      
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return GoalSituationDialog(
            playerCount: _selectedYourTeamPlayersOnIce.length,
            detectedSituation: detectedSituation,
            onConfirm: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          );
        },
      );
      
      if (confirmed != true) {
        setState(() { _isLogging = false; });
        return;
      }
    }

    setState(() { _isLogging = true; });

    try {
      GameEvent eventToProcess;
      String successMessage;

      if (_isEditMode && _eventBeingEdited != null) {
        print('Updating existing shot event:');
        print('  ID: ${_eventBeingEdited!.id}');
        print('  IsGoal before: ${_eventBeingEdited!.isGoal}');
        
        _eventBeingEdited!.period = _selectedPeriod;
        _eventBeingEdited!.team = _selectedTeam;
        _eventBeingEdited!.primaryPlayerId = _selectedTeam == widget.teamId ? _selectedShooter?.id ?? '' : '';
        _eventBeingEdited!.assistPlayer1Id = _isGoal ? _selectedAssist1?.id : null;
        _eventBeingEdited!.isGoal = _isGoal;
        _eventBeingEdited!.isSynced = false;
        _eventBeingEdited!.yourTeamPlayersOnIce = _isGoal ? _getPlayersOnIceIds() : null;
        _eventBeingEdited!.goalSituation = _isGoal ? _detectGoalSituation() : null;
        _eventBeingEdited!.goalieOnIceId = (_selectedTeam == 'opponent' && _selectedGoalie != null) ? _selectedGoalie!.id : null;
        
        print('  IsGoal after: ${_eventBeingEdited!.isGoal}');
        
        eventToProcess = _eventBeingEdited!;
        successMessage = 'Shot updated for ${(_selectedTeam == widget.teamId && _selectedShooter != null) ? '#${_selectedShooter!.jerseyNumber} ' : ''}$_selectedTeam${_isGoal ? " (Goal)" : ""}';
        
        await gameEventsBox.put(eventToProcess.id, eventToProcess);
        print('Event updated in Hive');

        final savedEvent = gameEventsBox.get(eventToProcess.id);
        print('Verified saved event:');
        print('  ID: ${savedEvent?.id}');
        print('  IsGoal: ${savedEvent?.isGoal}');
        
        bool syncSuccess = false;
        String syncError = '';
        try {
          syncSuccess = await _sheetsService.updateEventInSheet(eventToProcess);
          if (!syncSuccess) {
            syncError = "Sync failed - please try again later.";
          }
        } catch (error) {
          syncError = error.toString();
          print("Error during sync for updated event: $error");
        }

        if (!mounted) return;

        if (syncSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successMessage and synced.')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shot updated locally but sync failed: $syncError'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry Sync',
                onPressed: _logShot,
              ),
            ),
          );
        }

      } else {
        print('Creating new shot event:');
        print('  Team: $_selectedTeam');
        print('  IsGoal: $_isGoal');
        
        final newShotEvent = GameEvent(
          id: uuid.v4(),
          gameId: widget.gameId,
          timestamp: DateTime.now(),
          period: _selectedPeriod,
          eventType: 'Shot',
          team: _selectedTeam,
          primaryPlayerId: _selectedTeam == widget.teamId ? _selectedShooter?.id ?? '' : '',
          assistPlayer1Id: _isGoal ? _selectedAssist1?.id : null,
          assistPlayer2Id: null, 
          isGoal: _isGoal,
          isSynced: false,
          yourTeamPlayersOnIce: _isGoal ? _getPlayersOnIceIds() : null,
          goalSituation: _isGoal ? _detectGoalSituation() : null,
          goalieOnIceId: (_selectedTeam == 'opponent' && _selectedGoalie != null) ? _selectedGoalie!.id : null,
        );
        
        eventToProcess = newShotEvent;
        successMessage = 'Shot logged for ${(_selectedTeam == widget.teamId && _selectedShooter != null) ? '#${_selectedShooter!.jerseyNumber} ' : ''}$_selectedTeam${_isGoal ? " (Goal)" : ""}';

        print('Saving new event to Hive:');
        print('  ID: ${eventToProcess.id}');
        print('  IsGoal: ${eventToProcess.isGoal}');
        
        await gameEventsBox.put(eventToProcess.id, eventToProcess);
        
        final savedEvent = gameEventsBox.get(eventToProcess.id);
        print('Verified saved event:');
        print('  ID: ${savedEvent?.id}');
        print('  IsGoal: ${savedEvent?.isGoal}');

        bool syncSuccess = false;
        String syncError = '';
        try {
          syncSuccess = await _sheetsService.syncGameEvent(eventToProcess);
          if (!syncSuccess) {
            syncError = "Sync failed - please try again later.";
          }
        } catch (error) {
          syncError = error.toString();
          print("Error during sync for new event: $error");
        }

        if (!mounted) return;

        if (syncSuccess) {
          Navigator.pop(context, _selectedPeriod);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successMessage and synced.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Shot saved locally - will sync when online'),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, _selectedPeriod);
        }
      }

    } catch (e) {
      print('Error in _logShot: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing shot: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() { _isLogging = false; });
      }
    }
  }

  List<String> _getPlayersOnIceIds() {
    return _selectedYourTeamPlayersOnIce.map((player) => player.id).toList();
  }

  GoalSituation _detectGoalSituation() {
    if (_isPowerPlay) {
      return GoalSituation.powerPlay;
    } else if (_isPenaltyKill) {
      return GoalSituation.shortHanded;
    } else {
      return GoalSituation.evenStrength;
    }
  }

  void _selectPlayersOnIce() async {
    List<Player> tempSelectedPlayers = List.from(_selectedYourTeamPlayersOnIce);
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Players On Ice'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _yourTeamPlayers.map((player) {
                    final isAbsent = _isPlayerAbsent(player);
                    return CheckboxListTile(
                      title: Row(
                        children: [
                          Text(
                            '#${player.jerseyNumber}',
                            style: TextStyle(
                              color: isAbsent ? Colors.grey : null,
                            ),
                          ),
                          if (isAbsent) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.person_off,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '(Absent)',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      value: tempSelectedPlayers.contains(player),
                      onChanged: isAbsent 
                          ? null  // Disable checkbox for absent players
                          : (bool? value) {
                              setState(() {
                                if (value == true) {
                                  if (!tempSelectedPlayers.contains(player)) {
                                    if (tempSelectedPlayers.length < 5) {
                                      tempSelectedPlayers.add(player);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Maximum 5 players can be selected'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  tempSelectedPlayers.remove(player);
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    this.setState(() {
                      _selectedYourTeamPlayersOnIce = tempSelectedPlayers;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeOpponentPlayers() {
    final playersBox = Hive.box<Player>('players');
    final opponentPlayers = playersBox.values.where((player) => player.teamId != widget.teamId).toList();
    for (var player in opponentPlayers) {
      player.delete();
    }
  }

  Widget _buildTeamSelectionButton({
    required String teamName,
    required String teamIdentifier,
    required Widget logo,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
            backgroundColor: isSelected 
                ? (teamIdentifier == widget.teamId ? Colors.blue.withOpacity(0.3) : Colors.red.withOpacity(0.3)) 
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: isSelected 
                    ? (teamIdentifier == widget.teamId ? Colors.blue : Colors.red) 
                    : Colors.grey.withOpacity(0.5),
                width: 2.0,
              ),
            ),
            elevation: isSelected ? 4 : 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              logo,
              const SizedBox(height: 8.0),
              Text(
                teamName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
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
  
  // Helper methods for the integrated player selection UI
  
  Widget _buildRoleIndicator(String label, IconData icon, Color color, int count, [String? subtitle]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Color _getPlayerBackgroundColor(bool isOnIce, bool isShooter, bool isAssist, bool isAbsent) {
    if (isAbsent) return Colors.grey.withOpacity(0.3);
    if (isShooter) return Colors.green.withOpacity(0.2);
    if (isAssist) return Colors.orange.withOpacity(0.2);
    if (isOnIce) return Colors.blue.withOpacity(0.2);
    return Colors.grey.withOpacity(0.1);
  }
  
  Color _getPlayerBorderColor(bool isOnIce, bool isShooter, bool isAssist, bool isAbsent) {
    if (isAbsent) return Colors.grey;
    if (isShooter) return Colors.green;
    if (isAssist) return Colors.orange;
    if (isOnIce) return Colors.blue;
    return Colors.grey.withOpacity(0.5);
  }
  
  Color _getPlayerTextColor(bool isOnIce, bool isShooter, bool isAssist, bool isAbsent) {
    if (isAbsent) return Colors.grey;
    if (isShooter) return Colors.green;
    if (isAssist) return Colors.orange;
    if (isOnIce) return Colors.blue;
    return Colors.black87;
  }
  
  void _showPlayerRoleDialog(Player player) {
    final isOnIce = _selectedYourTeamPlayersOnIce.contains(player);
    final isShooter = _selectedShooter == player;
    final isAssist = _selectedAssist1 == player;
    final isAbsent = _isPlayerAbsent(player);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text('Player #${player.jerseyNumber}'),
              if (isAbsent) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.person_off,
                  size: 16,
                  color: Colors.grey,
                ),
                const Text(
                  ' (Absent)',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAbsent)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'This player is marked as absent and cannot be selected.',
                    style: TextStyle(
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.sports_hockey, color: Colors.blue),
                title: const Text('On Ice'),
                trailing: Switch(
                  value: isOnIce,
                  activeColor: Colors.blue,
                  onChanged: isAbsent ? null : (value) {
                    setState(() {
                      if (value) {
                        if (_selectedYourTeamPlayersOnIce.length < 5) {
                          _selectedYourTeamPlayersOnIce.add(player);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Maximum 5 players can be on ice'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        _selectedYourTeamPlayersOnIce.remove(player);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sports_score, color: Colors.green),
                title: const Text('Goal Scorer'),
                trailing: Switch(
                  value: isShooter,
                  activeColor: Colors.green,
                  onChanged: isAbsent ? null : (value) {
                    setState(() {
                      if (value) {
                        _selectedShooter = player;
                      } else if (_selectedShooter == player) {
                        _selectedShooter = null;
                      }
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.handshake, color: Colors.orange),
                title: const Text('Assist'),
                trailing: Switch(
                  value: isAssist,
                  activeColor: Colors.orange,
                  onChanged: isAbsent ? null : (value) {
                    setState(() {
                      if (value) {
                        _selectedAssist1 = player;
                      } else if (_selectedAssist1 == player) {
                        _selectedAssist1 = null;
                      }
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _selectedPeriod);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'Edit Shot' : 'Log Shot'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ViewStatsScreen(gameId: widget.gameId, teamId: widget.teamId)),
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
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 20.0),

                FutureBuilder<String>(
                  future: TeamContextService().getCurrentTeamName(),
                  builder: (context, snapshot) {
                    final currentTeamName = snapshot.data ?? 'Your Team';
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTeamSelectionButton(
                          teamName: currentTeamName,
                          teamIdentifier: widget.teamId,
                          logo: TeamUtils.getTeamLogo(currentTeamName, size: 52, context: context),
                          isSelected: _selectedTeam == widget.teamId,
                          onPressed: () {
                            setState(() {
                              _selectedTeam = widget.teamId;
                              _filterPlayersByTeam();
                            });
                          },
                        ),
                        _buildTeamSelectionButton(
                          teamName: 'Opponent',
                          teamIdentifier: 'opponent',
                          logo: TeamUtils.getTeamLogo('Opponent', size: 52, context: context),
                          isSelected: _selectedTeam == 'opponent',
                          onPressed: () {
                            setState(() {
                              _selectedTeam = 'opponent';
                              _filterPlayersByTeam();
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20.0),


                // Shot Result Checkboxes
                CheckboxListTile(
                  title: const Text('Was it a goal?', style: TextStyle(fontSize: 16)),
                  value: _isGoal,
                  onChanged: (value) {
                    setState(() {
                      _isGoal = value!;
                    });
                  },
                ),

                if (_isGoal) ...[
                  const SizedBox(height: 16),
                  
                  // Goal Situation Selection
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Goal Situation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('Power Play'),
                                  value: _isPowerPlay,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _isPowerPlay = value ?? false;
                                      if (_isPowerPlay) {
                                        _isPenaltyKill = false; // Only one can be selected
                                      }
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('Penalty Kill'),
                                  value: _isPenaltyKill,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _isPenaltyKill = value ?? false;
                                      if (_isPenaltyKill) {
                                        _isPowerPlay = false; // Only one can be selected
                                      }
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ),
                            ],
                          ),
                          if (!_isPowerPlay && !_isPenaltyKill)
                            const Text(
                              'Default: Even Strength',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Use shared player selection widget
                  PlayerSelectionWidget(
                    players: _yourTeamPlayers,
                    goalies: _goalies,
                    absentPlayerIds: _absentPlayerIds,
                    selectedPlayersOnIce: _selectedYourTeamPlayersOnIce,
                    selectedGoalScorer: _selectedShooter,
                    selectedAssist1: _selectedAssist1,
                    selectedGoalie: _selectedGoalie,
                    onPlayersOnIceChanged: (players) {
                      setState(() {
                        _selectedYourTeamPlayersOnIce = players;
                      });
                    },
                    onGoalScorerChanged: (player) {
                      setState(() {
                        _selectedShooter = player;
                      });
                    },
                    onAssist1Changed: (player) {
                      setState(() {
                        _selectedAssist1 = player;
                      });
                    },
                    onGoalieChanged: (player) {
                      setState(() {
                        _selectedGoalie = player;
                      });
                    },
                  ),
                ],

                const SizedBox(height: 16.0),

                ElevatedButton(
                  onPressed: _isLogging ? null : _logShot,
                  child: _isLogging
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Logging...', style: TextStyle(fontSize: 16)),
                        ],
                      )
                    : Text(
                        _isEditMode ? 'Update Shot' : 'Log Shot',
                        style: const TextStyle(fontSize: 16),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
