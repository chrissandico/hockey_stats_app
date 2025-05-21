import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:hockey_stats_app/services/sheets_service.dart'; // Import the service

class LogPenaltyScreen extends StatefulWidget {
  final String gameId;
  final int period; // Add period parameter

  const LogPenaltyScreen({
    super.key, 
    required this.gameId,
    required this.period,
  });

  @override
  _LogPenaltyScreenState createState() => _LogPenaltyScreenState();
}

class _LogPenaltyScreenState extends State<LogPenaltyScreen> {
  // State variables for input values
  late int _selectedPeriod; // To store the currently selected period
  Player? _selectedPlayer;
  String? _penaltyType;
  int? _penaltyDuration;

  // Hive Box for GameEvents
  late Box<GameEvent> gameEventsBox;
  // Hive Box for Players
  late Box<Player> playersBox;
  // Service for Google Sheets interaction
  late SheetsService _sheetsService; // Add service instance

  // Uuid generator for unique IDs
  final uuid = Uuid();

  // List of players for the dropdown
  List<Player> _yourTeamPlayers = [];

  // List of common penalty types
  final List<String> _commonPenaltyTypes = [
    'Tripping',
    'Hooking',
    'Slashing',
    'Interference',
    'Roughing',
    'High-sticking',
    'Cross-checking',
    'Holding',
    'Delay of Game',
    'Unsportsmanlike Conduct',
    'Too Many Men',
    'Boarding',
    'Charging',
    'Elbowing',
    'Fighting',
    'Kneeing',
    'Spearing',
    // Add more common penalties as needed
  ];


  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.period; // Initialize _selectedPeriod
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    playersBox = Hive.box<Player>('players');
    _sheetsService = SheetsService(); // Initialize service
    _loadPlayers();
  }

  void _loadPlayers() {
    // Fetch players from Hive 'players' box for "your_team"
    _yourTeamPlayers = playersBox.values.where((p) => p.teamId == 'your_team').toList();
    if (_yourTeamPlayers.isNotEmpty) {
      // Optionally set a default selected player or leave it null
      // _selectedPlayer = _yourTeamPlayers.first;
    }
     setState(() {}); // Update the UI after loading players
  }

  // State variable for loading indicator
  bool _isLogging = false;

  Future<void> _logPenalty() async {
    if (_selectedPlayer == null || _penaltyType == null || _penaltyType!.isEmpty || _penaltyDuration == null || _penaltyDuration! <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all penalty details correctly.')),
      );
      return;
    }

    // Show loading indicator
    setState(() { _isLogging = true; });

    try {
      final newPenaltyEvent = GameEvent(
        id: uuid.v4(),
        gameId: widget.gameId,
        timestamp: DateTime.now(),
        period: _selectedPeriod,
        eventType: 'Penalty',
        team: 'your_team', // Assuming penalties are only for 'Your Team'
        primaryPlayerId: _selectedPlayer!.id,
        penaltyType: _penaltyType,
        penaltyDuration: _penaltyDuration,
        isSynced: false,
      );

      // Save to Hive
      await gameEventsBox.put(newPenaltyEvent.id, newPenaltyEvent);

      // Attempt sync to Google Sheets and wait for result
      bool syncSuccess = false;
      String syncError = '';
      try {
        syncSuccess = await _sheetsService.syncGameEvent(newPenaltyEvent);
        if (syncSuccess) {
          print("Penalty event ${newPenaltyEvent.id} synced successfully.");
        } else {
          syncError = "Sync failed - please try again later.";
          print("Penalty event ${newPenaltyEvent.id} sync failed.");
        }
      } catch (error) {
        syncError = error.toString();
        print("Error during sync for penalty event ${newPenaltyEvent.id}: $error");
      }

      // If all operations are successful
      if (!mounted) return;

      if (syncSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Penalty logged and synced for #${_selectedPlayer!.jerseyNumber}.')),
        );

        // Clear the form
        setState(() {
          _selectedPlayer = null;
          _penaltyType = null;
          _penaltyDuration = null;
          _isLogging = false;
        });
        
        // Navigate back
        Navigator.pop(context, _selectedPeriod);
      } else {
        // Show error but keep form data for retry
          Navigator.pop(context, _selectedPeriod);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Penalty saved locally - will sync when online'),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() { _isLogging = false; });
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging penalty: ${e.toString()}')),
      );
      print('Error in _logPenalty: $e');
      setState(() { _isLogging = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _selectedPeriod);
        return false; // We've handled the pop, so prevent default system pop.
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Log Penalty'),
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
              children: <Widget>[
                // New Period Selector
                _buildPeriodSelector(),
                const SizedBox(height: 16.0), // Add some spacing after the period selector

                // Player Selection
                DropdownButtonFormField<Player>(
                  decoration: const InputDecoration(labelText: 'Penalized Player'),
                  value: _selectedPlayer,
                  items: _yourTeamPlayers.map((player) {
                    return DropdownMenuItem<Player>(
                      value: player,
                      child: Text('#${player.jerseyNumber}', style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (Player? newValue) {
                    setState(() {
                      _selectedPlayer = newValue;
                    });
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 16.0),

                // Penalty Type Selection (Dropdown with common types)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Penalty Type'),
                  value: _penaltyType,
                  items: _commonPenaltyTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type, style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _penaltyType = newValue;
                    });
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 16.0),

                // Penalty Duration Input
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Penalty Duration (minutes)'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _penaltyDuration = int.tryParse(value);
                    });
                  },
                  // Clear the field when the form is cleared
                  controller: _penaltyDuration == null ? null : TextEditingController(text: _penaltyDuration.toString()),
                ),
                const SizedBox(height: 24.0),

                // Log Penalty Button with loading state
                ElevatedButton(
                  onPressed: _isLogging ? null : _logPenalty,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
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
                    : const Text('Log Penalty', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ), // This closes the Padding for body
      ), // This closes the Scaffold
    ); // This closes the WillPopScope
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
