import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // Import Hive
import 'package:hockey_stats_app/models/data_models.dart'; // Import your data models
import 'package:hockey_stats_app/screens/view_stats_screen.dart'; // Import the ViewStatsScreen
import 'package:uuid/uuid.dart'; // Package for generating unique IDs
import 'package:hockey_stats_app/utils/team_utils.dart'; // Import team utils for logos
import 'package:hockey_stats_app/services/sheets_service.dart'; // Import the SheetsService

// We'll need a way to select players. For simplicity, we'll use dummy data for now.
// In a real app, this would come from your LocalDatabase 'players' box.
// This list should ideally be passed to the screen or fetched based on the selected game's teams.


class LogShotScreen extends StatefulWidget {
  final String gameId; // Accept the gameId
  final int period; // Accept the period
  final String? eventIdToEdit; // Optional ID of event to edit

  const LogShotScreen({
    super.key, 
    required this.gameId,
    required this.period,
    this.eventIdToEdit, // Optional parameter for edit mode
  }); // Require gameId and period in constructor

  @override
  _LogShotScreenState createState() => _LogShotScreenState();
}

class _LogShotScreenState extends State<LogShotScreen> {
  // State variables to hold the input values
  late int _selectedPeriod; // To store the currently selected period
  bool _isGoal = false;
  String _selectedTeam = 'Your Team'; // Default team
  Player? _selectedShooter;
  Player? _selectedAssist1;
  Player? _selectedAssist2;
  // New state variable for players on ice
  List<Player> _selectedYourTeamPlayersOnIce = [];

  // Helper method to build styled team selection buttons
  Widget _buildTeamSelectionButton({
    required String teamName,
    required String teamIdentifier, // 'Your Team' or 'Opponent'
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
                ? (teamIdentifier == 'Your Team' ? Colors.blue.withOpacity(0.3) : Colors.red.withOpacity(0.3)) 
                : Theme.of(context).colorScheme.surfaceVariant,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: isSelected 
                    ? (teamIdentifier == 'Your Team' ? Colors.blue : Colors.red) 
                    : Colors.grey.withOpacity(0.5),
                width: 2.0,
              ),
            ),
            elevation: isSelected ? 4 : 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              logo, // Use the provided logo widget
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // When the user presses the back button (either app bar or system),
        // pop with the currently selected period on this screen.
        Navigator.pop(context, _selectedPeriod);
        // Return false because we've handled the pop manually.
        // Return true if you want the system to handle the pop after your code.
        return false; 
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'Edit Shot' : 'Log Shot'),
          // The default back button in AppBar will trigger onWillPop.
          actions: [ // Ensure actions is part of AppBar
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
                // New Period Selector
                _buildPeriodSelector(),
                const SizedBox(height: 20.0), // Add some spacing after the period selector

                // New Team Selection Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTeamSelectionButton(
                      teamName: 'Waxers', // Or your actual team name variable
                      teamIdentifier: 'Your Team',
                      logo: TeamUtils.getTeamLogo('Waxers', size: 52), // Larger logo
                      isSelected: _selectedTeam == 'Your Team',
                      onPressed: () {
                        setState(() {
                          _selectedTeam = 'Your Team';
                          _filterPlayersByTeam();
                        });
                      },
                    ),
                    _buildTeamSelectionButton(
                      teamName: 'Opponent',
                      teamIdentifier: 'Opponent',
                      logo: TeamUtils.getTeamLogo('Opponent', size: 52), // Larger logo
                      isSelected: _selectedTeam == 'Opponent',
                      onPressed: () {
                        setState(() {
                          _selectedTeam = 'Opponent';
                          _filterPlayersByTeam();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20.0), // Spacing after team selection

                // Is Goal Checkbox
                CheckboxListTile(
                  title: const Text('Was it a goal?', style: TextStyle(fontSize: 16),),
                  value: _isGoal,
                  onChanged: (value) {
                    setState(() {
                      _isGoal = value!;
                    });
                  },
                ),
                // Shooter Selection (Conditional)
                if (_selectedTeam == 'Your Team')
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
                // Assist Selection (Conditional)
                if (_isGoal && _selectedTeam == 'Your Team')
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
                // Players on Ice Button (Conditional - show when it's a goal)
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
                const SizedBox(height: 16.0), // Add spacing
                // Log/Update Shot Button
                ElevatedButton(
                  onPressed: _logShot,
                  child: Text(
                    _isEditMode ? 'Update Shot' : 'Log Shot', 
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ), // This closes the Padding for body
      ), // This closes the Scaffold
    ); // This closes the WillPopScope
  }


  // Hive Box for GameEvents
  late Box<GameEvent> gameEventsBox;
  // Service for Google Sheets interaction
  late SheetsService _sheetsService; // Add service instance

  // Uuid generator for unique IDs
  final uuid = Uuid();

  // Filtered player lists based on selected team
  List<Player> _playersForTeam = [];
  List<Player> _yourTeamPlayers = []; // List of players from 'Your Team'


  // Flag to indicate if we're in edit mode
  bool _isEditMode = false;
  // Store the event being edited
  GameEvent? _eventBeingEdited;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.period; // Initialize _selectedPeriod
    // Open the GameEvents box. It should already be open from main,
    // but it's good practice to get a reference here.
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    // Initialize SheetsService (assuming it doesn't need context or async init)
    // If SheetsService needed async init, we'd handle it differently.
    _sheetsService = SheetsService(); 

    // --- Load players from Hive instead of dummy data ---
    // In a real app, you'd filter players based on the selected game's teams.
    // For now, we'll just use the dummy list as the source.
    _loadPlayers();

    // Remove opponent players from the Hive box
    _removeOpponentPlayers();

    // Initialize selected shooter/assists with players from the loaded list
    _filterPlayersByTeam(); // Filter initially based on default team
    
    // Check if we're in edit mode
    if (widget.eventIdToEdit != null) {
      _loadEventForEditing();
    } else {
      // Default initialization for new shot
      if (_playersForTeam.isNotEmpty) {
        _selectedShooter = _playersForTeam.first;
      }
      _selectedAssist1 = null; // Initially no assist selected
      _selectedAssist2 = null; // Initially no assist selected
    }
  }

 // Function to load players (currently from dummy list, will be from Hive)
  void _loadPlayers() {
    // Fetch players from Hive 'players' box
    final playersBox = Hive.box<Player>('players');
    _yourTeamPlayers = playersBox.values.where((p) => p.teamId == 'your_team').toList();
  }

  // Function to filter players based on the currently selected team
  void _filterPlayersByTeam() {
    setState(() {
      final playersBox = Hive.box<Player>('players');
      if (_selectedTeam == 'Your Team') {
        _playersForTeam = playersBox.values.where((p) => p.teamId == 'your_team').toList();
      } else {
        _playersForTeam.clear();
        _selectedShooter = null;
      }
    });
  }


  // Load event data for editing
  void _loadEventForEditing() {
    try {
      // Get the event from Hive
      _eventBeingEdited = gameEventsBox.get(widget.eventIdToEdit);
      
      if (_eventBeingEdited != null) {
        // Set edit mode flag
        _isEditMode = true;
        
        // Populate form fields with event data
        setState(() {
          _selectedPeriod = _eventBeingEdited!.period;
          _isGoal = _eventBeingEdited!.isGoal ?? false;
          _selectedTeam = _eventBeingEdited!.team;
          
          // Load shooter if it's your team
          if (_selectedTeam == 'Your Team' && _eventBeingEdited!.primaryPlayerId.isNotEmpty) {
            try {
              _selectedShooter = _yourTeamPlayers.firstWhere(
                (player) => player.id == _eventBeingEdited!.primaryPlayerId
              );
            } catch (e) {
              print('Shooter not found: ${_eventBeingEdited!.primaryPlayerId}');
              _selectedShooter = null;
            }
          }
          
          // Load assist if it's a goal
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
          
          // Load players on ice if it's a goal
          if (_isGoal && _eventBeingEdited!.yourTeamPlayersOnIceIds != null) {
            _selectedYourTeamPlayersOnIce = _yourTeamPlayers.where(
              (player) => _eventBeingEdited!.yourTeamPlayersOnIceIds!.contains(player.id)
            ).toList();
          }
        });
      }
    } catch (e) {
      print('Error loading event for editing: $e');
      // If there's an error, fall back to creating a new event
      _isEditMode = false;
    }
  }

  // Function to save or update the shot event
  Future<void> _logShot() async {
    // Basic validation
    if (_selectedTeam == 'Your Team' && _selectedShooter == null && _isGoal == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shooter.')),
      );
      return;
    }

    // Optional: Add a loading indicator state if desired
    // setState(() { _isLogging = true; });

    try {
      GameEvent eventToProcess;
      String successMessage;

      if (_isEditMode && _eventBeingEdited != null) {
        // Update existing event
        _eventBeingEdited!.period = _selectedPeriod;
        _eventBeingEdited!.team = _selectedTeam;
        _eventBeingEdited!.primaryPlayerId = _selectedTeam == 'Your Team' ? _selectedShooter?.id ?? '' : '';
        _eventBeingEdited!.assistPlayer1Id = _isGoal ? _selectedAssist1?.id : null;
        // _eventBeingEdited!.assistPlayer2Id remains null as per original logic
        _eventBeingEdited!.isGoal = _isGoal;
        _eventBeingEdited!.isSynced = false; // Mark as needing sync
        _eventBeingEdited!.yourTeamPlayersOnIceIds = _isGoal ? _getPlayersOnIceIds() : null;
        
        eventToProcess = _eventBeingEdited!;
        successMessage = 'Shot updated for ${(_selectedTeam == 'Your Team' && _selectedShooter != null) ? '#${_selectedShooter!.jerseyNumber} ' : ''}${_selectedTeam}${_isGoal ? " (Goal)" : ""}';
        
        // Save the updated event
        await gameEventsBox.put(eventToProcess.id, eventToProcess);

        // Update local season stats - REMOVED as season stats are now aggregated on view
        // await _sheetsService.updateLocalPlayerSeasonStatsOnEvent(eventToProcess);
        
        // Attempt to sync the updated event (fire and forget)
        _sheetsService.updateEventInSheet(eventToProcess).then((syncSuccess) {
          if (syncSuccess) {
            print("Updated event ${eventToProcess.id} synced/queued for sync.");
          } else {
            print("Updated event ${eventToProcess.id} saved locally, pending sync. Sync call failed or not authenticated.");
          }
        }).catchError((error) {
          print("Error during background sync for updated event ${eventToProcess.id}: $error");
        });

      } else {
        // Create a new event
        final newShotEvent = GameEvent(
          id: uuid.v4(),
          gameId: widget.gameId,
          timestamp: DateTime.now(),
          period: _selectedPeriod,
          eventType: 'Shot',
          team: _selectedTeam,
          primaryPlayerId: _selectedTeam == 'Your Team' ? _selectedShooter?.id ?? '' : '',
          assistPlayer1Id: _isGoal ? _selectedAssist1?.id : null,
          assistPlayer2Id: null, 
          isGoal: _isGoal,
          isSynced: false,
          yourTeamPlayersOnIceIds: _isGoal ? _getPlayersOnIceIds() : null,
        );
        eventToProcess = newShotEvent;
        successMessage = 'Shot logged for ${(_selectedTeam == 'Your Team' && _selectedShooter != null) ? '#${_selectedShooter!.jerseyNumber} ' : ''}${_selectedTeam}${_isGoal ? " (Goal)" : ""}';

        // Save the event to the Hive Box
        await gameEventsBox.put(eventToProcess.id, eventToProcess);

        // Update local season stats - REMOVED as season stats are now aggregated on view
        // await _sheetsService.updateLocalPlayerSeasonStatsOnEvent(eventToProcess);

        // Attempt to sync the newly added event (fire and forget)
        _sheetsService.syncGameEvent(eventToProcess).then((syncSuccess) {
          if (syncSuccess) {
            print("New event ${eventToProcess.id} synced/queued for sync.");
          } else {
            print("New event ${eventToProcess.id} saved locally, pending sync. Sync call failed or not authenticated.");
          }
        }).catchError((error) {
          print("Error during background sync for new event ${eventToProcess.id}: $error");
        });
      }

      // If all local operations are successful up to this point:
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );

      // Navigate back after a short delay
      await Future.delayed(const Duration(milliseconds: 500)); // Shorter delay
      if (!mounted) return;

      if (_isEditMode) {
        Navigator.pop(context); 
      } else {
        Navigator.pop(context, _selectedPeriod);
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing shot: ${e.toString()}')),
      );
      print('Error in _logShot: $e');
    } finally {
      // Optional: Hide loading indicator if shown
      // if (mounted) {
      //   setState(() { _isLogging = false; });
      // }
    }
  }

  // Function to get the IDs of players on ice
  List<String> _getPlayersOnIceIds() {
    return _selectedYourTeamPlayersOnIce.map((player) => player.id).toList();
  }

  // Function to show a dialog for selecting players on ice
  void _selectPlayersOnIce() async {
    // Create a temporary list to track selections
    List<Player> tempSelectedPlayers = List.from(_selectedYourTeamPlayersOnIce);
    
    // Show a dialog with checkboxes for each player
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
                    // Update the main state with the selected players
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

  // Function to remove opponent players from the Hive box
  void _removeOpponentPlayers() {
    final playersBox = Hive.box<Player>('players');
    final opponentPlayers = playersBox.values.where((player) => player.teamId != 'your_team').toList();
    for (var player in opponentPlayers) {
      player.delete();
    }
  }

  // --- Copied Period Selector Methods ---
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
  // --- End Copied Period Selector Methods ---
}
