import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/models/custom_adapters.dart'; // Import our custom adapters
import 'package:hockey_stats_app/screens/game_selection_screen.dart'; // Import the new Game Selection screen
import 'package:hockey_stats_app/screens/auth_wrapper_screen.dart'; // Import the Auth Wrapper screen
import 'package:hockey_stats_app/utils/team_utils.dart'; // Import TeamUtils
import 'package:hockey_stats_app/services/sheets_service.dart'; // Import SheetsService for initial sync
import 'package:hockey_stats_app/services/team_auth_service.dart'; // Import TeamAuthService
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

  // Wrap the entire initialization in a try-catch for better error handling
  try {
    print('Starting app initialization...');
    
    // Normal app initialization starts here for subsequent (non-reset) runs
    await Hive.initFlutter();
    
    // Initialize our migration manager first
    await HiveMigrationManager.initialize();
    
    // Register standard adapters
    // Note: Game adapter is registered by HiveMigrationManager
    Hive.registerAdapter(PlayerAdapter());
    Hive.registerAdapter(GameEventAdapter());
    Hive.registerAdapter(EmailSettingsAdapter());
    Hive.registerAdapter(GameRosterAdapter());
    
    // Open boxes with error handling
    await _safelyOpenHiveBoxes();
    
    print('App initialization completed successfully');
    
    // DO NOT call attemptInitialDataSyncIfSignedIn() or addDummyDataIfNeeded() here anymore.
    // The GameSelectionScreen (or a new AuthWrapperScreen) will handle this.
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('CRITICAL ERROR during app initialization: $e');
    print('Stack trace: $stackTrace');
    
    // Show error UI instead of crashing
    runApp(const AppErrorScreen());
  }
}

/// Safely open all Hive boxes with error recovery
Future<void> _safelyOpenHiveBoxes() async {
  print('Opening Hive boxes with error handling...');
  
  // List of box names to open
  final boxNames = ['players', 'games', 'gameEvents', 'emailSettings', 'gameRoster'];
  
  for (final boxName in boxNames) {
    try {
      print('Opening box: $boxName');
      
      if (boxName == 'games') {
        // Special handling for games box which has migration
        await Hive.openBox<Game>(boxName);
      } else if (boxName == 'players') {
        await Hive.openBox<Player>(boxName);
      } else if (boxName == 'gameEvents') {
        await Hive.openBox<GameEvent>(boxName);
      } else if (boxName == 'emailSettings') {
        await Hive.openBox<EmailSettings>(boxName);
      } else if (boxName == 'gameRoster') {
        await Hive.openBox<GameRoster>(boxName);
      }
      
      print('Successfully opened box: $boxName');
    } catch (e) {
      print('Error opening box $boxName: $e');
      print('Attempting recovery...');
      
      try {
        // Try to recover the corrupted box
        await HiveMigrationManager.recoverCorruptedBox(boxName);
        print('Recovery successful for box: $boxName');
      } catch (recoveryError) {
        print('Recovery failed for box $boxName: $recoveryError');
        // Continue with other boxes even if one fails
      }
    }
  }
}

/// Error screen shown when app initialization fails
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'App Initialization Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  'There was a problem loading the app data. This might be due to corrupted data or a version mismatch.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    // Reset all data and restart the app
                    await _resetAllHiveData();
                    // This is a simple way to "restart" - just rebuild from scratch
                    main();
                  },
                  child: const Text('Reset Data & Restart'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        print('Initial data sync successful: ${syncResult['players']} players, ${syncResult['games']} games, and ${syncResult['events']} events synced.');
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
      // The home screen is now the AuthWrapperScreen
      home: MultiProvider(
        providers: [
          Provider(create: (_) => SheetsService()),
          Provider(create: (_) => TeamAuthService()),
        ],
        child: const AuthWrapperScreen(),
      ),
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
