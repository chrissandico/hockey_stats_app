import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:hockey_stats_app/models/data_models.dart'; // Assuming your models are here
import 'package:hive/hive.dart'; // Import Hive

// Define the scopes required for Google Sheets access
// spreadsheets scope gives read/write access. Use .readonly for read-only.
const _scopes = [sheets.SheetsApi.spreadsheetsScope];

class SheetsService {
  // TODO: Replace with your actual Spreadsheet ID
  final String _spreadsheetId = '1u4olfiYFjXW0Z88U3Q1wOxI7gz04KYbg6LNn8h-rfno'; 

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    // Optional: If you have a Web Client ID for backend verification
    // serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com', 
  );

  // Store the signed-in account
  GoogleSignInAccount? _currentUser;

  // Store the authenticated HTTP client
  auth.AuthClient? _authClient;

  // --- Authentication ---

  // Check if user is already signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Get the current user
  GoogleSignInAccount? getCurrentUser() {
    return _currentUser;
  }

  // Attempt to sign in silently
  Future<bool> signInSilently() async {
    _currentUser = await _googleSignIn.signInSilently();
    if (_currentUser != null) {
      await _setupAuthClient();
      return true;
    }
    return false;
  }

  // Initiate interactive sign-in
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        await _setupAuthClient();
        return true;
      }
      return false;
    } catch (error) {
      print('Error signing in: $error');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _authClient = null;
  }

  // Setup the authenticated client
  Future<void> _setupAuthClient() async {
    if (_currentUser == null) return;
    _authClient = await _googleSignIn.authenticatedClient();
  }

  // --- Google Sheets API Interaction ---

  // Helper to get the Sheets API instance
  sheets.SheetsApi? _getSheetsApi() {
    if (_authClient == null) {
      print('Error: User not authenticated.');
      // Try to refresh the auth client if we have a user but no client
      if (_currentUser != null) {
        print('Attempting to refresh authentication...');
        // We can't await here since this method isn't async
        // Instead, return null and let the caller handle re-authentication
      }
      return null;
    }
    print('Auth client exists, creating Sheets API instance');
    return sheets.SheetsApi(_authClient!);
  }

  // Check and refresh authentication if needed
  Future<bool> ensureAuthenticated() async {
    if (_authClient != null) {
      print('Auth client already exists');
      return true; // Already authenticated
    }
    
    if (_currentUser == null) {
      print('No current user, attempting silent sign-in');
      // Try silent sign-in first
      _currentUser = await _googleSignIn.signInSilently();
    }
    
    if (_currentUser != null) {
      print('User exists (${_currentUser!.email}), setting up auth client');
      await _setupAuthClient();
      return _authClient != null;
    }
    
    print('No user and no auth client, authentication failed');
    return false;
  }

  // Fetch player roster data from the Players sheet
  Future<List<Player>?> fetchPlayers() async {
    // First ensure we're authenticated
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot fetch players: Authentication failed.');
      return null;
    }
    
    // Now get the API instance
    final sheetsApi = _getSheetsApi();
    if (sheetsApi == null) {
      print('Cannot fetch players: Sheets API not available even after authentication check.');
      return null;
    }

    // Define the sheet name and range
    final String range = 'Players!A2:D'; // Columns: ID, Jersey Number, Team ID, Position (starting from row 2)

    try {
      print('Fetching players from Google Sheet...');
      final result = await sheetsApi.spreadsheets.values.get(
        _spreadsheetId,
        range,
      );

      final values = result.values;
      if (values == null || values.isEmpty) {
        print('No player data found in the sheet.');
        return [];
      }

      print('Found ${values.length} player records in the sheet.');
      
      // Parse the values into Player objects
      List<Player> players = [];
      for (var row in values) {
        if (row.length >= 2) { // Need at least ID and Jersey Number
          try {
             // Column A: ID (String)
             String id = row[0]?.toString() ?? '';
             
             // Column B: Jersey Number (int)
             int jerseyNumber = int.tryParse(row[1]?.toString() ?? '') ?? 0;
             
             // Column C: Team ID (String, optional)
             String? teamId = row.length > 2 ? row[2]?.toString() : 'your_team';

             // Column D: Position (String, optional)
             String? position = row.length > 3 ? row[3]?.toString() : null;
             if (position != null && position.trim().isEmpty) {
               position = null; // Treat empty strings as null for 'N/A' display
             }
             
             if (id.isNotEmpty && jerseyNumber >= 0) {
                players.add(Player(
                  id: id, 
                  jerseyNumber: jerseyNumber,
                  teamId: teamId,
                  position: position, // Add position
                ));
                print('Parsed player: #$jerseyNumber (ID: $id, Pos: $position)');
             } else {
                print('Skipping invalid player row: $row (ID or jersey number invalid)');
             }
          } catch (e) {
             print('Error parsing player row: $row, Error: $e');
          }
        } else {
          print('Skipping player row with insufficient data: $row');
        }
      }
      
      print('Successfully parsed ${players.length} players from the sheet.');
      return players;

    } catch (e) {
      print('Error fetching players from Google Sheet: $e');
      return null;
    }
  }

  // Append a GameEvent to the Events sheet
  // Returns true if sync is successful, false otherwise.
  Future<bool> syncGameEvent(GameEvent event) async {
     // First ensure we're authenticated
     bool isAuthenticated = await ensureAuthenticated();
     if (!isAuthenticated) {
        print('Cannot sync event: Authentication failed.');
        return false;
     }
     
     // Now get the API instance
     final sheetsApi = _getSheetsApi();
     if (sheetsApi == null) {
        print('Cannot sync event: Sheets API not available even after authentication check.');
        return false;
     }

     // *** IMPORTANT: Update sheet name if different ***
     const String sheetName = 'Events'; 
     // Range notation 'SheetName!A1' tells Sheets API to append after the last row with data
     final String range = '$sheetName!A1'; 

     // Convert GameEvent to a list of values matching the sheet column order
     // *** IMPORTANT: Adjust the order and content based on your actual sheet columns ***
     final List<Object> values = [
       event.id, // Column A: Event ID
       event.gameId, // Column B: Game ID
       event.timestamp.toIso8601String(), // Column C: Timestamp (ISO 8601 format)
       event.period, // Column D: Period
       event.eventType, // Column E: Event Type ("Shot", "Penalty")
       event.team, // Column F: Team ("Your Team", "Opponent")
       event.primaryPlayerId, // Column G: Primary Player ID (Shooter/Penalized)
       event.assistPlayer1Id ?? '', // Column H: Assist 1 ID (Handle null)
       event.assistPlayer2Id ?? '', // Column I: Assist 2 ID (Handle null)
       event.isGoal ?? false, // Column J: Is Goal (TRUE/FALSE)
       event.penaltyType ?? '', // Column K: Penalty Type (Handle null)
       event.penaltyDuration ?? 0, // Column L: Penalty Duration (Handle null)
       event.yourTeamPlayersOnIceIds?.join(',') ?? '', // Column M: Players on Ice (comma-separated IDs, handle null)
     ];

     // ValueRange object required by the API
     final valueRange = sheets.ValueRange()
       ..values = [values]; // API expects a list of rows (even if it's just one row)

     try {
       // Perform the append operation
       final result = await sheetsApi.spreadsheets.values.append(
         valueRange, // The data to append
         _spreadsheetId, // The ID of the spreadsheet
         range, // The range (SheetName!A1 indicates append)
         valueInputOption: 'USER_ENTERED', // How the data should be interpreted by Sheets
         // Other options: 'RAW' (no parsing), 'USER_ENTERED' (like typing in UI)
       );

       // Check the result - successful append usually updates some cells/rows
       if (result.updates != null && (result.updates!.updatedCells ?? 0) > 0) {
         print('Successfully synced event ${event.id}');
         // Update the local event's sync status
         if (event.isInBox) { // Check if the object is still managed by Hive
            event.isSynced = true;
            await event.save(); // Save the change back to Hive
         }
         return true;
       } else {
         print('Sync successful according to API, but no cells were updated. Result: ${result.toJson()}');
         // Consider this a success for now, but might need investigation
         if (event.isInBox) {
            event.isSynced = true;
            await event.save();
         }
         return true; 
       }
     } catch (e) {
       // Handle potential API errors (e.g., network issues, permission errors)
       print('Error syncing event ${event.id} to Google Sheets: $e');
       // TODO: Implement more robust error handling (e.g., retry logic, user feedback)
      return false;
     }
  }

  // Sync all locally stored events that haven't been synced yet
  Future<Map<String, int>> syncPendingEvents() async {
    // First ensure we're authenticated
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync pending events: Authentication failed.');
      return {'success': 0, 'failed': 0, 'pending': -1}; // Indicate auth failure
    }
    
    // Now get the API instance
    final sheetsApi = _getSheetsApi();
    if (sheetsApi == null) {
      print('Cannot sync pending events: Sheets API not available even after authentication check.');
      return {'success': 0, 'failed': 0, 'pending': -1}; // Indicate auth failure
    }

    final gameEventsBox = Hive.box<GameEvent>('gameEvents');
    // Find events that are not synced
    final pendingEvents = gameEventsBox.values.where((event) => !event.isSynced).toList();

    if (pendingEvents.isEmpty) {
      print('No pending events to sync.');
      return {'success': 0, 'failed': 0, 'pending': 0};
    }

    print('Found ${pendingEvents.length} pending events to sync.');
    int successCount = 0;
    int failureCount = 0;

    // Loop through and sync each pending event
    for (final event in pendingEvents) {
      // Check again if authenticated before each attempt (token might expire)
      if (_authClient == null) {
         print('Authentication lost during batch sync.');
         failureCount = pendingEvents.length - successCount; // Mark remaining as failed
         break; // Stop syncing if auth is lost
      }
      
      bool success = await syncGameEvent(event); // Reuse the single event sync logic
      if (success) {
        successCount++;
      } else {
        failureCount++;
        // Optional: Implement retry logic here for failures
      }
      // Optional: Add a small delay between API calls to avoid rate limits
      // await Future.delayed(const Duration(milliseconds: 100)); 
    }

    print('Sync complete. Success: $successCount, Failed: $failureCount');
    return {'success': successCount, 'failed': failureCount, 'pending': failureCount}; // Return remaining pending count
  }

  // Fetch game schedule data from the Games sheet
  Future<List<Game>?> fetchGames() async {
    // First ensure we're authenticated
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot fetch games: Authentication failed.');
      return null;
    }
    
    // Now get the API instance
    final sheetsApi = _getSheetsApi();
    if (sheetsApi == null) {
      print('Cannot fetch games: Sheets API not available even after authentication check.');
      return null;
    }

    // Define the sheet name and range
    final String range = 'Games!A2:D'; // Columns: ID, Date, Opponent, Location (starting from row 2)

    try {
      print('Fetching games from Google Sheet...');
      final result = await sheetsApi.spreadsheets.values.get(
        _spreadsheetId,
        range,
      );

      final values = result.values;
      if (values == null || values.isEmpty) {
        print('No game data found in the sheet.');
        return [];
      }

      print('Found ${values.length} game records in the sheet.');
      
      // Parse the values into Game objects
      List<Game> games = [];
      for (var row in values) {
        if (row.length >= 3) { // Need at least ID, Date, and Opponent
          try {
             // Column A: ID (String)
             String id = row[0]?.toString() ?? '';
             
             // Column B: Date (DateTime)
             DateTime date;
             try {
               // Try to parse date from various formats
               String dateStr = row[1]?.toString() ?? '';
               // First try ISO format (YYYY-MM-DD)
               if (dateStr.contains('-')) {
                 date = DateTime.parse(dateStr);
               } 
               // Try MM/DD/YYYY format
               else if (dateStr.contains('/')) {
                 final parts = dateStr.split('/');
                 if (parts.length == 3) {
                   final month = int.parse(parts[0]);
                   final day = int.parse(parts[1]);
                   final year = int.parse(parts[2]);
                   date = DateTime(year, month, day);
                 } else {
                   throw FormatException('Invalid date format: $dateStr');
                 }
               } else {
                 throw FormatException('Unrecognized date format: $dateStr');
               }
             } catch (e) {
               print('Error parsing date for game: $row, Error: $e');
               continue; // Skip this row if date can't be parsed
             }
             
             // Column C: Opponent (String)
             String opponent = row[2]?.toString() ?? '';
             
             // Column D: Location (String, optional)
             String? location = row.length > 3 ? row[3]?.toString() : null;
             
             if (id.isNotEmpty && opponent.isNotEmpty) {
                games.add(Game(
                  id: id, 
                  date: date,
                  opponent: opponent,
                  location: location,
                ));
                print('Parsed game: $opponent on ${date.toIso8601String().split('T')[0]} (ID: $id)');
             } else {
                print('Skipping invalid game row: $row (ID or opponent invalid)');
             }
          } catch (e) {
             print('Error parsing game row: $row, Error: $e');
          }
        } else {
          print('Skipping game row with insufficient data: $row');
        }
      }
      
      print('Successfully parsed ${games.length} games from the sheet.');
      return games;

    } catch (e) {
      print('Error fetching games from Google Sheet: $e');
      return null;
    }
  }

  // Sync both players and games from Google Sheets to local Hive database
  Future<Map<String, dynamic>> syncDataFromSheets() async {
    print('Starting full data sync from Google Sheets...');
    
    // First ensure we're authenticated
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync data: Authentication failed.');
      return {
        'success': false,
        'message': 'Authentication failed',
        'players': null,
        'games': null
      };
    }
    
    // Fetch players
    print('Fetching players...');
    final players = await fetchPlayers();
    if (players == null) {
      print('Failed to fetch players.');
      return {
        'success': false,
        'message': 'Failed to fetch players',
        'players': null,
        'games': null
      };
    }
    
    // Fetch games
    print('Fetching games...');
    final games = await fetchGames();
    if (games == null) {
      print('Failed to fetch games.');
      return {
        'success': false,
        'message': 'Failed to fetch games',
        'players': players, // Return players even if games failed
        'games': null
      };
    }
    
    // Save players to Hive
    print('Saving ${players.length} players to local database...');
    final playersBox = Hive.box<Player>('players');
    
    // Clear existing players with teamId 'your_team' (keep any other teams)
    final existingPlayers = playersBox.values.where((p) => p.teamId == 'your_team').toList();
    for (final player in existingPlayers) {
      await player.delete();
    }
    
    // Add new players
    for (final player in players) {
      await playersBox.put(player.id, player);
    }
    
    // Save games to Hive
    print('Saving ${games.length} games to local database...');
    final gamesBox = Hive.box<Game>('games');
    
    // Option 1: Clear all existing games and replace with new ones
    // await gamesBox.clear();
    
    // Option 2: Update existing games and add new ones
    for (final game in games) {
      await gamesBox.put(game.id, game);
    }
    
    print('Data sync complete. Synced ${players.length} players and ${games.length} games.');
    return {
      'success': true,
      'message': 'Sync completed successfully',
      'players': players.length,
      'games': games.length
    };
  }

  // Update an existing event in the Google Sheet
  // This method finds the row with the matching event ID and updates it
  Future<bool> updateEventInSheet(GameEvent event) async {
    // First ensure we're authenticated
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot update event: Authentication failed.');
      return false;
    }
    
    // Now get the API instance
    final sheetsApi = _getSheetsApi();
    if (sheetsApi == null) {
      print('Cannot update event: Sheets API not available even after authentication check.');
      return false;
    }

    // Define the sheet name
    const String sheetName = 'Events';
    
    try {
      // First, we need to find the row that contains this event ID
      // Get all IDs from column A
      final idRange = await sheetsApi.spreadsheets.values.get(
        _spreadsheetId,
        '$sheetName!A:A', // Get all values in column A (Event IDs)
      );
      
      final idValues = idRange.values;
      if (idValues == null || idValues.isEmpty) {
        print('No data found in the Events sheet.');
        return false;
      }
      
      // Find the row index where the ID matches
      int rowIndex = -1;
      for (int i = 0; i < idValues.length; i++) {
        if (idValues[i].isNotEmpty && idValues[i][0] == event.id) {
          rowIndex = i + 1; // Sheets API uses 1-based indexing
          break;
        }
      }
      
      if (rowIndex == -1) {
        print('Event ID ${event.id} not found in the sheet. Cannot update.');
        // If the event doesn't exist in the sheet, try to append it instead
        return await syncGameEvent(event);
      }
      
      // Prepare the data to update
      final List<Object> values = [
        event.id, // Column A: Event ID
        event.gameId, // Column B: Game ID
        event.timestamp.toIso8601String(), // Column C: Timestamp (ISO 8601 format)
        event.period, // Column D: Period
        event.eventType, // Column E: Event Type ("Shot", "Penalty")
        event.team, // Column F: Team ("Your Team", "Opponent")
        event.primaryPlayerId, // Column G: Primary Player ID (Shooter/Penalized)
        event.assistPlayer1Id ?? '', // Column H: Assist 1 ID (Handle null)
        event.assistPlayer2Id ?? '', // Column I: Assist 2 ID (Handle null)
        event.isGoal ?? false, // Column J: Is Goal (TRUE/FALSE)
        event.penaltyType ?? '', // Column K: Penalty Type (Handle null)
        event.penaltyDuration ?? 0, // Column L: Penalty Duration (Handle null)
        event.yourTeamPlayersOnIceIds?.join(',') ?? '', // Column M: Players on Ice (comma-separated IDs, handle null)
      ];
      
      // Create the update range (the entire row for this event)
      final updateRange = '$sheetName!A$rowIndex:M$rowIndex';
      
      // Create the ValueRange object
      final valueRange = sheets.ValueRange()
        ..values = [values]; // API expects a list of rows
      
      // Perform the update
      final result = await sheetsApi.spreadsheets.values.update(
        valueRange,
        _spreadsheetId,
        updateRange,
        valueInputOption: 'USER_ENTERED', // How the data should be interpreted by Sheets
      );
      
      // Check the result
      if (result.updatedCells != null && result.updatedCells! > 0) {
        print('Successfully updated event ${event.id} in row $rowIndex');
        // Update the local event's sync status
        if (event.isInBox) {
          event.isSynced = true;
          await event.save();
        }
        return true;
      } else {
        print('Update API call succeeded but no cells were updated. Result: ${result.toJson()}');
        return false;
      }
    } catch (e) {
      print('Error updating event ${event.id} in Google Sheets: $e');
      return false;
    }
  }

  // --- Local Stats Update ---
  // Method `updateLocalPlayerSeasonStatsOnEvent` removed as PlayerSeasonStats are no longer stored in Hive or synced separately.
  // Season stats will be aggregated on-the-fly in ViewSeasonStatsScreen.

  // Helper method `_syncPlayerSeasonStatsToSheet` removed as PlayerSeasonStats are no longer stored in Hive or synced separately.

  // --- Season Stats Sync ---
  // Method `syncSeasonStatsToSheet` and `_ensureSheetExists` removed as PlayerSeasonStats are no longer synced to a separate sheet.
  // All related code for these methods has been deleted.
}
