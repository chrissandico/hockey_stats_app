import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';

class LogShotScreen extends StatefulWidget {
  final String gameId;
  final int period;
  final String? eventIdToEdit;

  const LogShotScreen({
    super.key, 
    required this.gameId,
    required this.period,
    this.eventIdToEdit,
  });

  @override
  _LogShotScreenState createState() => _LogShotScreenState();
}

class _LogShotScreenState extends State<LogShotScreen> {
  // State variables to hold the input values
  late int _selectedPeriod;
  bool _isGoal = false;
  String _selectedTeam = 'your_team';
  Player? _selectedShooter;
  Player? _selectedAssist1;
  Player? _selectedAssist2;
  List<Player> _selectedYourTeamPlayersOnIce = [];

  // Hive Box for GameEvents
  late Box<GameEvent> gameEventsBox;
  late SheetsService _sheetsService;

  // Uuid generator for unique IDs
  final uuid = Uuid();

  // Filtered player lists based on selected team
  List<Player> _playersForTeam = [];
  List<Player> _yourTeamPlayers = [];

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
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    _sheetsService = SheetsService();
    _loadPlayers();
    _removeOpponentPlayers();
    _filterPlayersByTeam();
    
    if (widget.eventIdToEdit != null) {
      _loadEventForEditing();
    } else {
      if (_playersForTeam.isNotEmpty) {
        _selectedShooter = _playersForTeam.first;
      }
      _selectedAssist1 = null;
      _selectedAssist2 = null;
    }
  }

  void _loadPlayers() {
    final playersBox = Hive.box<Player>('players');
    _yourTeamPlayers = playersBox.values.where((p) => p.teamId == 'your_team').toList();
  }

  void _filterPlayersByTeam() {
    setState(() {
      final playersBox = Hive.box<Player>('players');
      if (_selectedTeam == 'your_team') {
        _playersForTeam = playersBox.values.where((p) => p.teamId == 'your_team').toList();
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
          
          if (_selectedTeam == 'your_team' && _eventBeingEdited!.primaryPlayerId.isNotEmpty) {
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
        });
      }
    } catch (e) {
      print('Error loading event for editing: $e');
      _isEditMode = false;
    }
  }

  Future<void> _logShot() async {
    if (_selectedTeam == 'your_team' && _selectedShooter == null && _isGoal == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shooter.')),
      );
      return;
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
        _eventBeingEdited!.primaryPlayerId = _selectedTeam == 'your_team' ? _selectedShooter?.id ?? '' : '';
        _eventBeingEdited!.assistPlayer1Id = _isGoal ? _selectedAssist1?.id : null;
        _eventBeingEdited!.isGoal = _isGoal;
        _eventBeingEdited!.isSynced = false;
        _eventBeingEdited!.yourTeamPlayersOnIce = _isGoal ? _getPlayersOnIceIds() : null;
        
        print('  IsGoal after: ${_eventBeingEdited!.isGoal}');
        
        eventToProcess = _eventBeingEdited!;
        successMessage = 'Shot updated for ${(_selectedTeam == 'your_team' && _selectedShooter != null) ? '#${_selectedShooter!.jerseyNumber} ' : ''}${_selectedTeam}${_isGoal ? " (Goal)" : ""}';
        
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
          primaryPlayerId: _selectedTeam == 'your_team' ? _selectedShooter?.id ?? '' : '',
          assistPlayer1Id: _isGoal ? _selectedAssist1?.id : null,
          assistPlayer2Id: null, 
          isGoal: _isGoal,
          isSynced: false,
          yourTeamPlayersOnIce: _isGoal ? _getPlayersOnIceIds() : null,
        );
        
        eventToProcess = newShotEvent;
        successMessage = 'Shot logged for ${(_selectedTeam == 'your_team' && _selectedShooter != null) ? '#${_selectedShooter!.jerseyNumber} ' : ''}${_selectedTeam}${_isGoal ? " (Goal)" : ""}';

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successMessage and synced.')),
          );
          Navigator.pop(context, _selectedPeriod);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shot saved locally but sync failed: $syncError'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry Sync',
                onPressed: _logShot,
              ),
            ),
          );
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
                    return CheckboxListTile(
                      title: Text('#${player.jerseyNumber}'),
                      value: tempSelectedPlayers.contains(player),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            if (!tempSelectedPlayers.contains(player)) {
                              tempSelectedPlayers.add(player);
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
    final opponentPlayers = playersBox.values.where((player) => player.teamId != 'your_team').toList();
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
                ? (teamIdentifier == 'your_team' ? Colors.blue.withOpacity(0.3) : Colors.red.withOpacity(0.3)) 
                : Theme.of(context).colorScheme.surfaceVariant,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: isSelected 
                    ? (teamIdentifier == 'your_team' ? Colors.blue : Colors.red) 
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
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 20.0),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTeamSelectionButton(
                      teamName: 'Waxers',
                      teamIdentifier: 'your_team',
                      logo: TeamUtils.getTeamLogo('Waxers', size: 52),
                      isSelected: _selectedTeam == 'your_team',
                      onPressed: () {
                        setState(() {
                          _selectedTeam = 'your_team';
                          _filterPlayersByTeam();
                        });
                      },
                    ),
                    _buildTeamSelectionButton(
                      teamName: 'Opponent',
                      teamIdentifier: 'opponent',
                      logo: TeamUtils.getTeamLogo('Opponent', size: 52),
                      isSelected: _selectedTeam == 'opponent',
                      onPressed: () {
                        setState(() {
                          _selectedTeam = 'opponent';
                          _filterPlayersByTeam();
                        });
                      },
                    ),
                  ],
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

                if (_selectedTeam == 'your_team')
                  DropdownButtonFormField<Player>(
                    decoration: const InputDecoration(labelText: 'Who shot it?'),
                    value: _selectedShooter,
                    items: _playersForTeam
                        .map((player) => DropdownMenuItem(
                              value: player,
                              child: Text('#${player.jerseyNumber}', style: const TextStyle(fontSize: 16),),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedShooter = value;
                      });
                    },
                  ),

                if (_isGoal && _selectedTeam == 'your_team')
                  DropdownButtonFormField<Player>(
                    decoration: const InputDecoration(labelText: 'Who assisted it?'),
                    value: _selectedAssist1,
                    items: _yourTeamPlayers
                        .map((player) => DropdownMenuItem(
                              value: player,
                              child: Text('#${player.jerseyNumber}', style: const TextStyle(fontSize: 16),),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAssist1 = value;
                      });
                    },
                  ),

                if (_isGoal)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.people),
                      label: Text(
                        'Select Players On Ice (${_selectedYourTeamPlayersOnIce.length})',
                        style: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _selectPlayersOnIce,
                    ),
                  ),

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
