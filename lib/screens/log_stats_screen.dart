import 'package:flutter/material.dart';
import 'package:hockey_stats_app/screens/log_shot_screen.dart';
import 'package:hockey_stats_app/screens/log_penalty_screen.dart';
import 'package:hockey_stats_app/screens/view_stats_screen.dart';

// This screen will display the logging buttons after a game is selected.
// It receives the selected gameId.
class LogStatsScreen extends StatelessWidget {
  final String gameId; // The ID of the currently selected game

  const LogStatsScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch and display game details (e.g., opponent, date) using gameId from Hive
    // TODO: Add Period selection UI here

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Stats'), // Title indicating tracking mode
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ViewStatsScreen(gameId: gameId)),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
            // TODO: Display selected game details here
            const Text(
              'Logging Stats For:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Example: Replace with actual game details
            Text('Game ID: $gameId'), // Display the passed game ID for now
            const SizedBox(height: 30),

            // Buttons to navigate to specific logging screens
            ElevatedButton(
              onPressed: () {
                // Navigate to LogShotScreen, passing the selected gameId
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LogShotScreen(gameId: gameId)),
                );
              },
              child: const Text('Log Shot'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Navigate to LogPenaltyScreen, passing the selected gameId
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LogPenaltyScreen(gameId: gameId)),
                );
              },
              child: const Text('Log Penalty'),
            ),
            // TODO: Add button for View Local Stats (UF-5)
            // TODO: Add button for Sync Data (UF-4)
            ],
          ),
        ),
      ),
    );
  }
}
