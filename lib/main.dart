import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/screens/game_selection_screen.dart'; // Import the new Game Selection screen
import 'package:hockey_stats_app/utils/team_utils.dart'; // Import TeamUtils
import 'package:hockey_stats_app/services/sheets_service.dart'; // Import SheetsService for initial sync
// Removed imports for log_shot_screen and log_penalty_screen as we navigate via GameSelectionScreen now

// Define the dummyGameId here to be used across files (still needed for dummy data creation)
String dummyGameId = 'dummy_game_123';
String dummyGameId2 = 'dummy_game_456'; // Add another dummy game ID

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(GameEventAdapter());

  await Hive.openBox<Player>('players');
  await Hive.openBox<Game>('games');
  await Hive.openBox<GameEvent>('gameEvents');

  // Try to sync data from Google Sheets on app launch
  await attemptInitialDataSync();

  runApp(const MyApp());
}

// Attempt to sync data from Google Sheets on app launch
Future<void> attemptInitialDataSync() async {
  print('Attempting initial data sync from Google Sheets...');
  
  // Create an instance of SheetsService
  final sheetsService = SheetsService();
  
  // Check if the user is already signed in
  final isSignedIn = await sheetsService.isSignedIn();
  
  if (isSignedIn) {
    print('User is already signed in, attempting silent sign-in...');
    // Try silent sign-in
    final success = await sheetsService.signInSilently();
    
    if (success) {
      print('Silent sign-in successful, syncing data...');
      // Sync data from Google Sheets
      final result = await sheetsService.syncDataFromSheets();
      
      if (result['success'] == true) {
        print('Initial data sync successful: ${result['players']} players and ${result['games']} games synced.');
      } else {
        print('Initial data sync failed: ${result['message']}');
        // Fall back to dummy data if sync fails and boxes are empty
        addDummyDataIfNeeded();
      }
    } else {
      print('Silent sign-in failed, falling back to dummy data if needed.');
      // Fall back to dummy data if sign-in fails and boxes are empty
      addDummyDataIfNeeded();
    }
  } else {
    print('User is not signed in, falling back to dummy data if needed.');
    // Fall back to dummy data if user is not signed in and boxes are empty
    addDummyDataIfNeeded();
  }
}

// Add dummy data if the boxes are empty
void addDummyDataIfNeeded() {
  print('Checking if dummy data is needed...');
  
  // --- Add some dummy data to the players box for testing ---
  var playersBox = Hive.box<Player>('players');
  if (playersBox.isEmpty) { // Only add if the box is empty
    print('Adding dummy players data...');
    playersBox.add(Player(id: 'player_1', jerseyNumber: 10, teamId: 'your_team'));
    playersBox.add(Player(id: 'player_2', jerseyNumber: 22, teamId: 'your_team'));
    playersBox.add(Player(id: 'player_3', jerseyNumber: 7, teamId: 'your_team'));
    playersBox.add(Player(id: 'player_4', jerseyNumber: 88, teamId: 'opponent_team'));
    playersBox.add(Player(id: 'player_5', jerseyNumber: 55, teamId: 'opponent_team'));
  }
  
  // --- Add dummy games to the games box for testing ---
  var gamesBox = Hive.box<Game>('games');
  if (gamesBox.isEmpty) { // Only add if the box is empty
    print('Adding dummy games data...');
    gamesBox.add(Game(id: dummyGameId, date: DateTime.now().subtract(Duration(days: 1)), opponent: 'Rivals'));
    gamesBox.add(Game(id: dummyGameId2, date: DateTime.now(), opponent: 'Chiefs'));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize TeamUtils when the app starts
    TeamUtils.initialize(context);
    
    return MaterialApp(
      title: 'Hockey Stats App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // The home screen is now the GameSelectionScreen
      home: const GameSelectionScreen(),
    );
  }
}

// Removed MyHomePage as it's no longer the primary home screen
/*
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center( // Center the content
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Hockey Stats Tracker Home',
              style: TextStyle(fontSize: 24), // Make title larger
            ),
            const SizedBox(height: 30), // Add some spacing
            ElevatedButton(
              onPressed: () {
                // Navigate to the LogShotScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LogShotScreen()),
                );
              },
              child: const Text('Log Shot'),
            ),
             const SizedBox(height: 10), // Add spacing between buttons
             ElevatedButton(
              onPressed: () {
                // Navigate to the LogPenaltyScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LogPenaltyScreen()),
                );
              },
              child: const Text('Log Penalty'),
            ),
            // Add buttons for other actions later (View Stats, Sync, etc.)
          ],
        ),
      ),
    );
  }
}
*/
