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

  const LogShotScreen({
    super.key, 
    required this.gameId,
    required this.period,
  }); // Require gameId and period in constructor

  @override
  _LogShotScreenState createState() => _LogShotScreenState();
}

class _LogShotScreenState extends State<LogShotScreen> {
  // State variables to hold the input values
  bool _isGoal = false;
  String _selectedTeam = 'Your Team'; // Default team
  Player? _selectedShooter;
  Player? _selectedAssist1;
  Player? _selectedAssist2;
  // New state variable for players on ice
  List<Player> _selectedYourTeamPlayersOnIce = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Shot'),
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
            // Period indicator at the top of the form with period change buttons
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: Colors.amber[800]),
                  const SizedBox(width: 8.0),
                  Text(
                    'Period ${widget.period == 4 ? "OT" : widget.period}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                  const Spacer(),
                  // Period change buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.amber[800],
                        onPressed: widget.period > 1 ? _decrementPeriod : null,
                        tooltip: 'Previous Period',
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.amber[800],
                        onPressed: widget.period < 4 ? _incrementPeriod : null,
                        tooltip: 'Next Period',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Team Selection with logos
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Which team?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Your Team option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTeam = 'Your Team';
                              _filterPlayersByTeam();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: _selectedTeam == 'Your Team' 
                                  ? Colors.blue.withOpacity(0.2) 
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: _selectedTeam == 'Your Team' 
                                    ? Colors.blue 
                                    : Colors.grey,
                                width: 2.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                TeamUtils.getTeamLogo('Waxers', size: 40),
                                const SizedBox(height: 4),
                                const Text(
                                  'Waxers',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Radio<String>(
                                  value: 'Your Team',
                                  groupValue: _selectedTeam,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTeam = value!;
                                      _filterPlayersByTeam();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Opponent option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTeam = 'Opponent';
                              _filterPlayersByTeam();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: _selectedTeam == 'Opponent' 
                                  ? Colors.red.withOpacity(0.2) 
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: _selectedTeam == 'Opponent' 
                                    ? Colors.red 
                                    : Colors.grey,
                                width: 2.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                TeamUtils.getTeamLogo('Opponent', size: 40),
                                const SizedBox(height: 4),
                                const Text(
                                  'Opponent',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Radio<String>(
                                  value: 'Opponent',
                                  groupValue: _selectedTeam,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTeam = value!;
                                      _filterPlayersByTeam();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
            // Log Shot Button
            ElevatedButton(
              onPressed: _logShot,
              child: const Text('Log Shot', style: TextStyle(fontSize: 16),),
            ),
            ],
          ),
        ),
      ),
    );
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


  @override
  void initState() {
    super.initState();
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
    if (_playersForTeam.isNotEmpty) {
       _selectedShooter = _playersForTeam.first;
    }
     _selectedAssist1 = null; // Initially no assist selected
     _selectedAssist2 = null; // Initially no assist selected
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


 // Function to save the shot event to Hive and attempt immediate sync
 Future<void> _logShot() async { // Mark method as async
    // Basic validation
    if (_selectedTeam == 'Your Team' && _selectedShooter == null && _isGoal == true) {
      // Show an error message (e.g., using a SnackBar)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shooter.')),
      );
      return;
    }

    // Create a new GameEvent object
    final newShotEvent = GameEvent(
      id: uuid.v4(), // Generate a unique ID for the event
      gameId: widget.gameId, // Use the gameId passed to the widget
      timestamp: DateTime.now(), // Record the current time
      period: widget.period, // Use the period passed to the widget
      eventType: 'Shot', // Set the event type
      team: _selectedTeam, // Set the team
      primaryPlayerId: _selectedTeam == 'Your Team' ? _selectedShooter?.id ?? '' : '', // Link to the shooter's Player ID
      assistPlayer1Id: _isGoal ? _selectedAssist1?.id : null, // Link assist 1 if it's a goal
      assistPlayer2Id: null, // No assist 2
      isGoal: _isGoal, // Set if it was a goal
      isSynced: false, // Mark as unsynced initially
      yourTeamPlayersOnIceIds: _isGoal ? _getPlayersOnIceIds() : null, // Include players on ice if it's a goal
    );

    // Save the event to the Hive Box
    await gameEventsBox.add(newShotEvent); // Use await for async add

    // Attempt to sync the newly added event immediately
    // We don't necessarily need to wait for this or block UI, 
    // but we might want to show feedback later based on sync status.
    // We pass the same newShotEvent object which will be updated by syncGameEvent if successful.
    _sheetsService.syncGameEvent(newShotEvent).then((syncSuccess) {
      if (syncSuccess) {
        print("Event ${newShotEvent.id} synced immediately.");
        // Optionally show different feedback if sync worked instantly
      } else {
        print("Event ${newShotEvent.id} saved locally, pending sync.");
        // The event is saved locally anyway, syncPendingEvents will catch it later
      }
    });


    // Optional: Show a confirmation message (indicates local save success)
    if (!mounted) return; // Check mounted before showing SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shot logged for ${(_selectedTeam == 'Your Team') ? '#${_selectedShooter!.jerseyNumber} ' : ''}${_selectedTeam}${_isGoal ? " (Goal)" : ""}')),
    );

    // Clear the form
    setState(() {
      _isGoal = false;
      _selectedTeam = 'Your Team';
      _filterPlayersByTeam(); // Re-filter players for the default team
      _selectedShooter = null;
      _selectedAssist1 = null;
      _selectedYourTeamPlayersOnIce = []; // Clear the selected players on ice
    });
    
    // Return to previous screen after a short delay to show the confirmation
    Future.delayed(const Duration(milliseconds: 1500), () {
      // Return the current period to the previous screen
      Navigator.pop(context, widget.period);
    });
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
  
  // Function to decrement the period
  void _decrementPeriod() {
    if (widget.period > 1) {
      // Create a new instance of LogShotScreen with the decremented period
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LogShotScreen(
            gameId: widget.gameId,
            period: widget.period - 1,
          ),
        ),
      );
    }
  }
  
  // Function to increment the period
  void _incrementPeriod() {
    if (widget.period < 4) {
      // Create a new instance of LogShotScreen with the incremented period
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LogShotScreen(
            gameId: widget.gameId,
            period: widget.period + 1,
          ),
        ),
      );
    }
  }
}
