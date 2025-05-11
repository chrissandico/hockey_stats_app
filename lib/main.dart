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

// Function to reset all Hive data
Future<void> _resetAllHiveData() async {
  print('Resetting all Hive data...');
  // Deletes all boxes from disk. This is a full reset.
  await Hive.deleteFromDisk(); 
  print('All Hive data has been reset.');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- TEMPORARY RESET LOGIC ---
  // STEP 1: Set performReset to true to reset data.
  // STEP 2: Run the app once. You'll see a message in the console.
  // STEP 3: Stop the app.
  // STEP 4: Set performReset back to false.
  // STEP 5: Restart the app for normal operation with fresh data.
  const bool performReset = false; // CHANGE TO true TO RESET

  if (performReset) {
    await Hive.initFlutter(); // Initialize Hive to allow deleteFromDisk call
    await _resetAllHiveData(); // This calls Hive.deleteFromDisk()
    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    print("!!! HIVE DATA RESET COMPLETE.                                !!!");
    print("!!! SET performReset back to false in lib/main.dart NOW,   !!!");
    print("!!! AND THEN RESTART THE APP.                              !!!");
    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    return; // Exit main early to prevent the rest of the app from running in this reset session.
  }
  // --- END TEMPORARY RESET LOGIC ---

  // Normal app initialization starts here for subsequent (non-reset) runs
  await Hive.initFlutter();

  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(GameEventAdapter());
  // Hive.registerAdapter(PlayerSeasonStatsAdapter()); // PlayerSeasonStats is no longer a HiveObject

  await Hive.openBox<Player>('players');
  await Hive.openBox<Game>('games');
  await Hive.openBox<GameEvent>('gameEvents');
  // await Hive.openBox<PlayerSeasonStats>('playerSeasonStats'); // This box is no longer used

  // DO NOT call attemptInitialDataSyncIfSignedIn() or addDummyDataIfNeeded() here anymore.
  // The GameSelectionScreen (or a new AuthWrapperScreen) will handle this.

  runApp(const MyApp());
}

// This function tries to sync if the user is already authenticated.
// It does NOT fall back to dummy data.
// The UI layer will decide if dummy data should be added based on the outcome.
Future<Map<String, dynamic>> attemptInitialDataSyncIfSignedIn() async {
  print('Attempting initial data sync from Google Sheets if signed in...');
  final sheetsService = SheetsService();
  
  // Check if a user session already exists (e.g. from a previous app run)
  final bool previousSessionExists = await sheetsService.isSignedIn();

  if (previousSessionExists) {
    print('User has a previous session, attempting silent sign-in to refresh credentials...');
    final bool silentSignInSuccess = await sheetsService.signInSilently();
    
    if (silentSignInSuccess) {
      print('Silent sign-in successful, proceeding to sync data...');
      final Map<String, dynamic> syncResult = await sheetsService.syncDataFromSheets();
      
      if (syncResult['success'] == true) {
        print('Initial data sync successful: ${syncResult['players']} players and ${syncResult['games']} games synced.');
        return {'status': 'sync_success', 'message': 'Sync successful', 'data': syncResult};
      } else {
        print('Initial data sync failed after successful sign-in: ${syncResult['message']}');
        return {'status': 'sync_failed', 'message': 'Data sync failed: ${syncResult['message']}'};
      }
    } else {
      print('Silent sign-in failed. User might need to sign in manually.');
      return {'status': 'signin_needed', 'message': 'Could not refresh session. Please sign in.'};
    }
  } else {
    print('User is not signed in. No sync attempted.');
    return {'status': 'signin_needed', 'message': 'Please sign in to sync your data.'};
  }
}

// Add dummy data if the boxes are empty.
// This function should be called explicitly by the UI when appropriate,
// not automatically on every startup if the user isn't signed in.
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
    // Use put with the game's ID as the key for consistency
    final game1 = Game(id: dummyGameId, date: DateTime.now().subtract(const Duration(days: 1)), opponent: 'Rivals');
    gamesBox.put(game1.id, game1);
    
    final game2 = Game(id: dummyGameId2, date: DateTime.now(), opponent: 'Chiefs');
    gamesBox.put(game2.id, game2);
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
