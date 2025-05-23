import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final List<String> _scopes = ['https://www.googleapis.com/auth/spreadsheets'];

class SheetsService {
  final String _spreadsheetId = '1u4olfiYFjXW0Z88U3Q1wOxI7gz04KYbg6LNn8h-rfno';
  final String _sheetsApiBase = 'https://sheets.googleapis.com/v4/spreadsheets';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  GoogleSignInAccount? _currentUser;
  auth.AuthClient? _authClient;

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  GoogleSignInAccount? getCurrentUser() {
    return _currentUser;
  }

  Future<bool> signInSilently() async {
    _currentUser = await _googleSignIn.signInSilently();
    if (_currentUser != null) {
      await _setupAuthClient();
      return true;
    }
    return false;
  }

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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _authClient = null;
  }

  Future<void> _setupAuthClient() async {
    if (_currentUser == null) return;
    _authClient = await _googleSignIn.authenticatedClient();
  }

  Future<Map<String, dynamic>?> _makeRequest(String method, String endpoint, {Map<String, dynamic>? body}) async {
    if (_authClient == null) {
      print('Error: User not authenticated.');
      return null;
    }

    final Uri uri = Uri.parse('$_sheetsApiBase/$_spreadsheetId/$endpoint');
    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _authClient!.get(uri);
          break;
        case 'POST':
          response = await _authClient!.post(
            uri,
            body: json.encode(body),
            headers: {'Content-Type': 'application/json'},
          );
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Request error: $e');
      return null;
    }
  }

  Future<bool> syncGameEvent(GameEvent event) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync event: Authentication failed.');
      return false;
    }

    // Format the timestamp in a more readable format: YYYY-MM-DD HH:MM:SS
    String formattedTimestamp = "${event.timestamp.year}-${event.timestamp.month.toString().padLeft(2, '0')}-${event.timestamp.day.toString().padLeft(2, '0')} ${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}";

    final List<Object> values = [
      event.id,
      event.gameId,
      formattedTimestamp,
      event.period,
      event.eventType,
      event.team,
      event.primaryPlayerId,
      event.assistPlayer1Id ?? '',
      event.assistPlayer2Id ?? '',
      event.isGoal ?? false,
      event.penaltyType ?? '',
      event.penaltyDuration ?? 0,
      event.yourTeamPlayersOnIce?.join(',') ?? '',
      event.version,
    ];

    final Map<String, dynamic> body = {
      'values': [values],
      'majorDimension': 'ROWS',
    };

    final result = await _makeRequest(
      'POST',
      'values/Events!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
      body: body,
    );

    if (result != null) {
      print('Successfully synced event ${event.id}');
      if (event.isInBox) {
        event.isSynced = true;
        await event.save();
      }
      return true;
    }
    return false;
  }

  Future<bool> updateEventInSheet(GameEvent event) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot update event: Authentication failed.');
      return false;
    }

    // First get all IDs to find the row
    final idResult = await _makeRequest('GET', 'values/Events!A:A');
    if (idResult == null) return false;

    final List<List<dynamic>> idValues = List<List<dynamic>>.from(idResult['values'] ?? []);
    int rowIndex = -1;
    for (int i = 0; i < idValues.length; i++) {
      if (idValues[i].isNotEmpty && idValues[i][0] == event.id) {
        rowIndex = i + 1;
        break;
      }
    }

    if (rowIndex == -1) {
      print('Event ID ${event.id} not found in the sheet. Cannot update.');
      return await syncGameEvent(event);
    }

    // Format the timestamp in a more readable format: YYYY-MM-DD HH:MM:SS
    String formattedTimestamp = "${event.timestamp.year}-${event.timestamp.month.toString().padLeft(2, '0')}-${event.timestamp.day.toString().padLeft(2, '0')} ${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}";

    final List<Object> values = [
      event.id,
      event.gameId,
      formattedTimestamp,
      event.period,
      event.eventType,
      event.team,
      event.primaryPlayerId,
      event.assistPlayer1Id ?? '',
      event.assistPlayer2Id ?? '',
      event.isGoal ?? false,
      event.penaltyType ?? '',
      event.penaltyDuration ?? 0,
      event.yourTeamPlayersOnIce?.join(',') ?? '',
    ];

    final Map<String, dynamic> body = {
      'values': [values],
      'majorDimension': 'ROWS',
    };

    final result = await _makeRequest(
      'POST',
      'values/Events!A$rowIndex:M$rowIndex?valueInputOption=USER_ENTERED',
      body: body,
    );

    if (result != null) {
      print('Successfully updated event ${event.id} in row $rowIndex');
      if (event.isInBox) {
        event.isSynced = true;
        await event.save();
      }
      return true;
    }
    return false;
  }

  Future<bool> ensureAuthenticated() async {
    if (_authClient != null) {
      print('Auth client already exists');
      return true;
    }
    
    if (_currentUser == null) {
      print('No current user, attempting silent sign-in');
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

  Future<Map<String, int>> syncPendingEvents() async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync pending events: Authentication failed.');
      return {'success': 0, 'failed': 0, 'pending': -1};
    }

    final gameEventsBox = Hive.box<GameEvent>('gameEvents');
    final pendingEvents = gameEventsBox.values.where((event) => !event.isSynced).toList();

    if (pendingEvents.isEmpty) {
      print('No pending events to sync.');
      return {'success': 0, 'failed': 0, 'pending': 0};
    }

    print('Found ${pendingEvents.length} pending events to sync.');
    int successCount = 0;
    int failureCount = 0;

    for (final event in pendingEvents) {
      if (_authClient == null) {
         print('Authentication lost during batch sync.');
         failureCount = pendingEvents.length - successCount;
         break;
      }
      
      bool success = await syncGameEvent(event);
      if (success) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    print('Sync complete. Success: $successCount, Failed: $failureCount');
    return {'success': successCount, 'failed': failureCount, 'pending': failureCount};
  }

  Future<List<Player>?> fetchPlayers() async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot fetch players: Authentication failed.');
      return null;
    }

    final result = await _makeRequest('GET', 'values/Players!A2:D');
    if (result == null) return null;

    final List<List<dynamic>> values = List<List<dynamic>>.from(result['values'] ?? []);
    if (values.isEmpty) {
      print('No player data found in the sheet.');
      return [];
    }

    print('Found ${values.length} player records in the sheet.');
    List<Player> players = [];

    for (var row in values) {
      if (row.length >= 2) {
        try {
          String id = row[0]?.toString() ?? '';
          int jerseyNumber = int.tryParse(row[1]?.toString() ?? '') ?? 0;
          String? teamId = row.length > 2 ? row[2]?.toString() : 'your_team';
          String? position = row.length > 3 ? row[3]?.toString() : null;
          
          if (position != null && position.trim().isEmpty) {
            position = null;
          }
          
          if (id.isNotEmpty && jerseyNumber >= 0) {
            players.add(Player(
              id: id,
              jerseyNumber: jerseyNumber,
              teamId: teamId,
              position: position,
            ));
            print('Parsed player: #$jerseyNumber (ID: $id, Pos: $position)');
          }
        } catch (e) {
          print('Error parsing player row: $row, Error: $e');
        }
      }
    }

    print('Successfully parsed ${players.length} players from the sheet.');
    return players;
  }

  Future<List<Game>?> fetchGames() async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot fetch games: Authentication failed.');
      return null;
    }

    final result = await _makeRequest('GET', 'values/Games!A2:D');
    if (result == null) return null;

    final List<List<dynamic>> values = List<List<dynamic>>.from(result['values'] ?? []);
    if (values.isEmpty) {
      print('No game data found in the sheet.');
      return [];
    }

    print('Found ${values.length} game records in the sheet.');
    List<Game> games = [];

    for (var row in values) {
      if (row.length >= 3) {
        try {
          String id = row[0]?.toString() ?? '';
          DateTime date;
          try {
            String dateStr = row[1]?.toString() ?? '';
            if (dateStr.contains('-')) {
              date = DateTime.parse(dateStr);
            } else if (dateStr.contains('/')) {
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
            continue;
          }
          
          String opponent = row[2]?.toString() ?? '';
          String? location = row.length > 3 ? row[3]?.toString() : null;
          
          if (id.isNotEmpty && opponent.isNotEmpty) {
            games.add(Game(
              id: id,
              date: date,
              opponent: opponent,
              location: location,
            ));
            print('Parsed game: $opponent on ${date.toIso8601String().split('T')[0]} (ID: $id)');
          }
        } catch (e) {
          print('Error parsing game row: $row, Error: $e');
        }
      }
    }

    print('Successfully parsed ${games.length} games from the sheet.');
    return games;
  }

  // Helper method to convert Excel numeric date to DateTime
  DateTime _excelDateToDateTime(double excelDate) {
    // Excel dates start from January 1, 1900
    // 1 = January 1, 1900
    // Excel has a leap year bug where it thinks 1900 was a leap year
    // So we need to adjust for dates after February 28, 1900
    
    // First, convert to days since 1899-12-30 (Excel epoch)
    final int days = excelDate.floor();
    
    // Convert days to DateTime (1899-12-30 + days)
    final DateTime dateTime = DateTime(1899, 12, 30).add(Duration(days: days));
    
    // Calculate time from the fractional part
    final double fractionalDay = excelDate - days;
    final int millisInDay = (fractionalDay * 24 * 60 * 60 * 1000).round();
    
    // Combine date and time
    return DateTime(
      dateTime.year, 
      dateTime.month, 
      dateTime.day,
      0, 0, 0, 
      millisInDay
    );
  }

  Future<List<GameEvent>?> fetchEvents() async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot fetch events: Authentication failed.');
      return null;
    }

    final result = await _makeRequest('GET', 'values/Events!A2:M');
    if (result == null) return null;

    final List<List<dynamic>> values = List<List<dynamic>>.from(result['values'] ?? []);
    if (values.isEmpty) {
      print('No event data found in the sheet.');
      return [];
    }

    print('Found ${values.length} event records in the sheet.');
    List<GameEvent> events = [];

    for (var row in values) {
      if (row.length >= 7) {
        try {
          String id = row[0]?.toString() ?? '';
          String gameId = row[1]?.toString() ?? '';
          DateTime timestamp;
          try {
            String dateStr = row[2]?.toString() ?? '';
            
            // Check if the date string is a numeric Excel date
            double? excelDate = double.tryParse(dateStr);
            if (excelDate != null) {
              // Convert Excel numeric date to DateTime
              timestamp = _excelDateToDateTime(excelDate);
              print('Converted Excel date $excelDate to ${timestamp.toIso8601String()}');
            } else if (dateStr.contains(' ')) {
              // Handle standard date format with space (e.g., "2023-05-22 14:30:00")
              var parts = dateStr.split(' ');
              var datePart = parts[0];
              var timePart = parts[1];
              var timeComponents = timePart.split(':');
              if (timeComponents[0].length == 1) {
                timeComponents[0] = '0${timeComponents[0]}';
              }
              dateStr = '$datePart ${timeComponents.join(':')}';
              timestamp = DateTime.parse(dateStr);
            } else {
              // Try standard parsing for other formats
              timestamp = DateTime.parse(dateStr);
            }
          } catch (e) {
            print('Error parsing timestamp: ${row[2]}, Error: $e');
            continue;
          }
          
          int period = int.tryParse(row[3]?.toString() ?? '') ?? 1;
          String eventType = row[4]?.toString() ?? '';
          String team = row[5]?.toString() ?? '';
          String primaryPlayerId = row[6]?.toString() ?? '';
          
          String? assistPlayer1Id = row.length > 7 ? row[7]?.toString() : null;
          if (assistPlayer1Id?.isEmpty ?? true) assistPlayer1Id = null;
          
          String? assistPlayer2Id = row.length > 8 ? row[8]?.toString() : null;
          if (assistPlayer2Id?.isEmpty ?? true) assistPlayer2Id = null;
          
          bool isGoal = row.length > 9 ? (row[9]?.toString().toLowerCase() == 'true') : false;
          
          String? penaltyType = row.length > 10 ? row[10]?.toString() : null;
          if (penaltyType?.isEmpty ?? true) penaltyType = null;
          
          int? penaltyDuration = row.length > 11 ? int.tryParse(row[11]?.toString() ?? '') : null;
          
          List<String>? playersOnIce = row.length > 12 && row[12]?.toString().isNotEmpty == true 
              ? row[12].toString().split(',')
              : null;

          if (id.isNotEmpty && gameId.isNotEmpty && (team == 'opponent' || primaryPlayerId.isNotEmpty)) {
            events.add(GameEvent(
              id: id,
              gameId: gameId,
              timestamp: timestamp,
              period: period,
              eventType: eventType,
              team: team,
              primaryPlayerId: primaryPlayerId,
              assistPlayer1Id: assistPlayer1Id,
              assistPlayer2Id: assistPlayer2Id,
              isGoal: isGoal,
              penaltyType: penaltyType,
              penaltyDuration: penaltyDuration,
              yourTeamPlayersOnIce: playersOnIce,
              isSynced: true,
              version: 1, // Initialize version for events from sheet
            ));
          }
        } catch (e) {
          print('Error parsing event row: $row, Error: $e');
        }
      }
    }

    print('Successfully parsed ${events.length} events from the sheet.');
    return events;
  }

  Future<Map<String, dynamic>> syncDataFromSheets() async {
    print('Starting full data sync from Google Sheets...');
    
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
    
    final games = await fetchGames();
    if (games == null) {
      print('Failed to fetch games.');
      return {
        'success': false,
        'message': 'Failed to fetch games',
        'players': players,
        'games': null
      };
    }
    
    final events = await fetchEvents();
    if (events == null) {
      print('Failed to fetch events.');
      return {
        'success': false,
        'message': 'Failed to fetch events',
        'players': players,
        'games': games,
        'events': null
      };
    }

    print('Saving data to local database...');
    
    final playersBox = Hive.box<Player>('players');
    final existingPlayers = playersBox.values.where((p) => p.teamId == 'your_team').toList();
    for (final player in existingPlayers) {
      await player.delete();
    }
    for (final player in players) {
      await playersBox.put(player.id, player);
    }
    
    final gamesBox = Hive.box<Game>('games');
    await gamesBox.clear();
    for (final game in games) {
      await gamesBox.put(game.id, game);
    }
    
    final eventsBox = Hive.box<GameEvent>('gameEvents');
    final unsyncedEvents = eventsBox.values.where((event) => !event.isSynced).toList();
    print('Found ${unsyncedEvents.length} unsynced local events');
    
    // Instead of deleting all synced events, we'll keep track of which events we've processed
    // from the Google Sheet and only delete events that are no longer in the sheet
    Set<String> remoteEventIds = events.map((e) => e.id).toSet();
    
    // Get all synced events that are not in the remote events list
    final syncedEventsToDelete = eventsBox.values
        .where((event) => event.isSynced && !remoteEventIds.contains(event.id))
        .toList();
    
    // Delete events that are no longer in the Google Sheet
    for (final event in syncedEventsToDelete) {
      print('Deleting event ${event.id} as it no longer exists in Google Sheets');
      await event.delete();
    }
    
    // Add or update events from Google Sheets
    for (final event in events) {
      if (!unsyncedEvents.any((e) => e.id == event.id)) {
        await eventsBox.put(event.id, event);
      }
    }
    
    for (final event in unsyncedEvents) {
      await eventsBox.put(event.id, event);
    }
    
    if (unsyncedEvents.isNotEmpty) {
      print('Attempting to sync ${unsyncedEvents.length} unsynced events...');
      for (final event in unsyncedEvents) {
        try {
          bool syncSuccess = await syncGameEvent(event);
          if (syncSuccess) {
            print('Successfully synced event ${event.id}');
            event.isSynced = true;
            await event.save();
          } else {
            print('Failed to sync event ${event.id}');
          }
        } catch (e) {
          print('Error syncing event ${event.id}: $e');
        }
      }
    }
    
    final remainingUnsyncedCount = eventsBox.values.where((event) => !event.isSynced).length;
    print('Sync complete. ${events.length} remote events processed. $remainingUnsyncedCount events remain unsynced.');
    
    return {
      'success': true,
      'message': 'Sync completed successfully',
      'players': players.length,
      'games': games.length,
      'events': events.length,
      'unsynced': remainingUnsyncedCount
    };
  }
}
