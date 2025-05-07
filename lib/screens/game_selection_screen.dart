import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // Import Hive
import 'package:hockey_stats_app/models/data_models.dart'; // Import your data models
import 'package:hockey_stats_app/screens/log_stats_screen.dart'; // We'll create a new screen to hold the logging buttons

// This screen will allow the user to select a game from the local database.
class GameSelectionScreen extends StatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  _GameSelectionScreenState createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  // Hive Box for Games
  late Box<Game> gamesBox;
  List<Game> availableGames = [];
  Game? _selectedGame;

  @override
  void initState() {
    super.initState();
    // Get a reference to the Games box
    gamesBox = Hive.box<Game>('games');
    // Load games from the box
    _loadGames();
  }

  void _loadGames() {
    // Get all games from the box and convert to a list
    setState(() {
      availableGames = gamesBox.values.toList();
      // Optionally pre-select the first game if available
      if (availableGames.isNotEmpty) {
        _selectedGame = availableGames.first;
      }
    });
  }

  // Function to handle game selection and navigation
  void _selectGameAndNavigate() {
    if (_selectedGame != null) {
      // Navigate to a screen where stats can be logged for the selected game.
      // We'll create a new screen called LogStatsScreen which will contain
      // the "Log Shot" and "Log Penalty" buttons, passing the selected game ID.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LogStatsScreen(gameId: _selectedGame!.id),
        ),
      );
    } else {
      // Show a message if no game is available or selected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a game.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Game'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch elements horizontally
            children: <Widget>[
            const Text(
              'Choose a game to track stats for:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),

            // Dropdown to select the game
            DropdownButtonFormField<Game>(
              decoration: const InputDecoration(labelText: 'Game'),
              value: _selectedGame,
              items: availableGames.map((Game game) {
                // Format the game display (e.g., Date vs Opponent)
                final gameTitle = '${game.date.toLocal().toString().split(' ')[0]} vs ${game.opponent}';
                return DropdownMenuItem<Game>(
                  value: game,
                  child: Text(gameTitle),
                );
              }).toList(),
              onChanged: (Game? newValue) {
                setState(() {
                  _selectedGame = newValue;
                });
              },
              // Add a hint text if no game is selected
              hint: const Text('Select a Game'),
            ),
            const SizedBox(height: 24.0),

            // Button to proceed after selecting a game
            ElevatedButton(
              onPressed: _selectGameAndNavigate,
              child: const Text('Start Tracking'),
            ),

            // Optional: Button to add a new game (future feature)
            // const SizedBox(height: 16.0),
            // OutlinedButton(
            //   onPressed: () {
            //     // TODO: Implement Add New Game functionality (UF-1 part 2)
            //   },
            //   child: const Text('Add New Game'),
            // ),
            ],
          ),
        ),
      ),
    );
  }
}
