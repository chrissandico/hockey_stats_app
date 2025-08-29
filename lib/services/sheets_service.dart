import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hockey_stats_app/services/service_account_auth.dart';

/// Service for interacting with Google Sheets to sync hockey stats data.
///
/// This service handles:
/// - Authentication with Google Service Account
/// - Reading data from Google Sheets (players, games, events)
/// - Writing data to Google Sheets (game events, attendance)
/// - Syncing local data with remote data
///
/// The service maintains a connection to a specific Google Spreadsheet that
/// serves as the central database for the hockey stats application.
class SheetsService {
  final String _spreadsheetId = '1u4olfiYFjXW0Z88U3Q1wOxI7gz04KYbg6LNn8h-rfno';
  final String _sheetsApiBase = 'https://sheets.googleapis.com/v4/spreadsheets';

  http.Client? _client;
  bool _isInitialized = false;

  /// Initialize the service with service account authentication
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      final serviceAuth = await ServiceAccountAuth.instance;
      _client = await serviceAuth.getClient();
      _isInitialized = true;
      print('SheetsService initialized with service account authentication');
    } catch (e) {
      print('Error initializing SheetsService: $e');
      _isInitialized = false;
      _client = null;
    }
  }

  /// Checks if the service is authenticated with the service account.
  ///
  /// @return A Future that resolves to true if authenticated, false otherwise
  Future<bool> isSignedIn() async {
    await _initialize();
    return _client != null;
  }

  /// Attempts to sign in silently using the service account.
  ///
  /// @return A Future that resolves to true if authentication was successful, false otherwise
  Future<bool> signInSilently() async {
    await _initialize();
    return _client != null;
  }

  /// Authenticates using the service account.
  ///
  /// @return A Future that resolves to true if authentication was successful, false otherwise
  Future<bool> signIn() async {
    await _initialize();
    return _client != null;
  }

  /// Clears the authentication state.
  Future<void> signOut() async {
    _client = null;
    _isInitialized = false;
  }
  
  /// Gets the service account email.
  ///
  /// This replaces the previous getCurrentUser() method which returned a GoogleSignInAccount.
  /// Since we're now using a service account, we return the service account email instead.
  String? getCurrentUser() {
    try {
      // Get the service account instance and return its email
      final serviceAuth = ServiceAccountAuth.instance;
      // Since instance is a Future, we can't directly access it here
      // Just return a placeholder for now
      return "service-account@hockey-stats-viewer.iam.gserviceaccount.com";
    } catch (e) {
      print('Error getting service account email: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _makeRequest(String method, String endpoint, {Map<String, dynamic>? body}) async {
    await _initialize();
    
    final Uri uri = Uri.parse('$_sheetsApiBase/$_spreadsheetId/$endpoint');
    http.Response response;

    try {
      // Get the service account auth instance
      final serviceAuth = await ServiceAccountAuth.instance;
      
      // Use the new makeAuthenticatedRequest method
      final headers = {'Content-Type': 'application/json'};
      
      switch (method) {
        case 'GET':
          response = await serviceAuth.makeAuthenticatedRequest(
            uri,
            method: 'GET',
            headers: headers,
          );
          break;
        case 'POST':
          response = await serviceAuth.makeAuthenticatedRequest(
            uri,
            method: 'POST',
            headers: headers,
            body: json.encode(body),
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

  Future<bool> syncGameRoster(GameRoster roster) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync roster: Authentication failed.');
      return false;
    }

    final List<Object> values = [
      roster.gameId,
      roster.playerId,
      roster.status,
    ];

    final Map<String, dynamic> body = {
      'values': [values],
      'majorDimension': 'ROWS',
    };

    final result = await _makeRequest(
      'POST',
      'values/GameRoster!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
      body: body,
    );

    if (result != null) {
      print('Successfully synced roster entry for player ${roster.playerId} in game ${roster.gameId}');
      if (roster.isInBox) {
        roster.isSynced = true;
        await roster.save();
      }
      return true;
    }
    return false;
  }

  Future<Map<String, int>> syncPendingRoster() async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync pending roster: Authentication failed.');
      return {'success': 0, 'failed': 0, 'pending': -1};
    }

    final gameRosterBox = Hive.box<GameRoster>('gameRoster');
    final pendingRoster = gameRosterBox.values.where((roster) => !roster.isSynced).toList();

    if (pendingRoster.isEmpty) {
      print('No pending roster entries to sync.');
      return {'success': 0, 'failed': 0, 'pending': 0};
    }

    print('Found ${pendingRoster.length} pending roster entries to sync.');
    int successCount = 0;
    int failureCount = 0;

    for (final roster in pendingRoster) {
      if (_client == null) {
         print('Authentication lost during batch sync.');
         failureCount = pendingRoster.length - successCount;
         break;
      }
      
      bool success = await syncGameRoster(roster);
      if (success) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    print('Roster sync complete. Success: $successCount, Failed: $failureCount');
    return {'success': successCount, 'failed': failureCount, 'pending': failureCount};
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
    await _initialize();
    return _client != null;
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
      if (_client == null) {
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

    final result = await _makeRequest('GET', 'values/Games!A2:E');
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
          String teamId = row.length > 4 ? row[4]?.toString() ?? 'your_team' : 'your_team'; // Default to 'your_team' if not specified
          
          if (id.isNotEmpty && opponent.isNotEmpty) {
            games.add(Game(
              id: id,
              date: date,
              opponent: opponent,
              location: location,
              teamId: teamId,
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

  /// Synchronizes all data from Google Sheets to the local database.
  ///
  /// This method:
  /// 1. Fetches players, games, and events from Google Sheets
  /// 2. Updates the local database with the fetched data
  /// 3. Attempts to sync any unsynced local events to Google Sheets
  ///
  /// @return A map containing the sync results, including success status and counts
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
    
    // Group players by team ID
    Map<String, List<Player>> playersByTeam = {};
    for (final player in players) {
      final teamId = player.teamId ?? 'your_team';
      if (!playersByTeam.containsKey(teamId)) {
        playersByTeam[teamId] = [];
      }
      playersByTeam[teamId]!.add(player);
    }
    
    // Update players for each team
    final playersBox = Hive.box<Player>('players');
    for (final teamId in playersByTeam.keys) {
      // Delete existing players for this team
      final existingPlayers = playersBox.values.where((p) => p.teamId == teamId).toList();
      for (final player in existingPlayers) {
        await player.delete();
      }
      
      // Add new players for this team
      for (final player in playersByTeam[teamId]!) {
        await playersBox.put(player.id, player);
      }
      
      print('Updated ${playersByTeam[teamId]!.length} players for team $teamId');
    }
    
    // Group games by team ID
    Map<String, List<Game>> gamesByTeam = {};
    for (final game in games) {
      final teamId = game.teamId;
      if (!gamesByTeam.containsKey(teamId)) {
        gamesByTeam[teamId] = [];
      }
      gamesByTeam[teamId]!.add(game);
    }
    
    // Update games for each team
    final gamesBox = Hive.box<Game>('games');
    for (final teamId in gamesByTeam.keys) {
      // Delete existing games for this team
      final existingGames = gamesBox.values.where((g) => g.teamId == teamId).toList();
      for (final game in existingGames) {
        await game.delete();
      }
      
      // Add new games for this team
      for (final game in gamesByTeam[teamId]!) {
        await gamesBox.put(game.id, game);
      }
      
      print('Updated ${gamesByTeam[teamId]!.length} games for team $teamId');
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
