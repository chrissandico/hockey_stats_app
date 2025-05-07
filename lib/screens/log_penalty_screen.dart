import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';
import 'package:uuid/uuid.dart';

class LogPenaltyScreen extends StatefulWidget {
  final String gameId;

  const LogPenaltyScreen({super.key, required this.gameId});

  @override
  _LogPenaltyScreenState createState() => _LogPenaltyScreenState();
}

class _LogPenaltyScreenState extends State<LogPenaltyScreen> {
  // State variables for input values
  Player? _selectedPlayer;
  String? _penaltyType;
  int? _penaltyDuration;

  // Hive Box for GameEvents
  late Box<GameEvent> gameEventsBox;
  // Hive Box for Players
  late Box<Player> playersBox;

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
    gameEventsBox = Hive.box<GameEvent>('gameEvents');
    playersBox = Hive.box<Player>('players');
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

  void _logPenalty() {
    if (_selectedPlayer == null || _penaltyType == null || _penaltyType!.isEmpty || _penaltyDuration == null || _penaltyDuration! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all penalty details correctly.')),
      );
      return;
    }

    final newPenaltyEvent = GameEvent(
      id: uuid.v4(),
      gameId: widget.gameId,
      timestamp: DateTime.now(),
      period: 1, // Assuming period 1 for now, add period selection later
      eventType: 'Penalty',
      team: 'Your Team', // Penalties are only for 'Your Team'
      primaryPlayerId: _selectedPlayer!.id,
      penaltyType: _penaltyType,
      penaltyDuration: _penaltyDuration,
      isSynced: false,
    );

    gameEventsBox.add(newPenaltyEvent);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Penalty logged for #${_selectedPlayer!.jerseyNumber}.')),
    );

    // Clear the form
    setState(() {
      _selectedPlayer = null;
      _penaltyType = null;
      _penaltyDuration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Penalty'),
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
            children: <Widget>[
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

            // Log Penalty Button
            ElevatedButton(
              onPressed: _logPenalty,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: const Text('Log Penalty', style: TextStyle(fontSize: 16)),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
