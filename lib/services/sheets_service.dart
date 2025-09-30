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
  DateTime? _lastAuthCheck;
  bool _isAuthenticated = false;
  
  // Cache authentication status for better performance
  static const Duration _authCacheValidDuration = Duration(minutes: 10);

  /// Initialize the service with service account authentication
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      final serviceAuth = await ServiceAccountAuth.instance;
      // We don't need to store the client anymore since we use makeAuthenticatedRequest
      _isInitialized = true;
      _isAuthenticated = true;
      _lastAuthCheck = DateTime.now();
      print('SheetsService initialized with service account authentication');
    } catch (e) {
      print('Error initializing SheetsService: $e');
      _isInitialized = false;
      _isAuthenticated = false;
    }
  }

  /// Checks if the service is authenticated with the service account.
  ///
  /// @return A Future that resolves to true if authenticated, false otherwise
  Future<bool> isSignedIn() async {
    await _initialize();
    return await ensureAuthenticated();
  }

  /// Attempts to sign in silently using the service account.
  ///
  /// @return A Future that resolves to true if authentication was successful, false otherwise
  Future<bool> signInSilently() async {
    await _initialize();
    return await ensureAuthenticated();
  }

  /// Authenticates using the service account.
  ///
  /// @return A Future that resolves to true if authentication was successful, false otherwise
  Future<bool> signIn() async {
    await _initialize();
    return await ensureAuthenticated();
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
        case 'PUT':
          response = await serviceAuth.makeAuthenticatedRequest(
            uri,
            method: 'PUT',
            headers: headers,
            body: json.encode(body),
          );
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          print('Error parsing JSON response: $e');
          print('Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');
          return null;
        }
      } else {
        // Check if response is HTML (error page) vs JSON error
        final responseBody = response.body;
        if (responseBody.trim().startsWith('<!DOCTYPE html') || responseBody.trim().startsWith('<html')) {
          print('API Error: ${response.statusCode} - Received HTML error page instead of JSON');
          print('This usually indicates authentication/permission issues or invalid spreadsheet ID');
          
          if (response.statusCode == 404) {
            print('404 Error: The spreadsheet may not exist or the service account may not have access');
            print('Service account email: ${serviceAuth.serviceAccountEmail}');
            print('Spreadsheet ID: $_spreadsheetId');
            print('Make sure the service account email is added to the spreadsheet with Editor permissions');
          }
          
          return null;
        } else {
          // Try to parse JSON error response
          try {
            final errorData = json.decode(responseBody);
            print('API Error: ${response.statusCode} - ${errorData}');
          } catch (e) {
            print('API Error: ${response.statusCode} - ${responseBody}');
          }
          return null;
        }
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
      _goalSituationToString(event.goalSituation),
      event.penaltyType ?? '',
      event.penaltyDuration ?? 0,
      event.yourTeamPlayersOnIce?.join(',') ?? '',
      event.goalieOnIceId ?? '',
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

    // Check if a row already exists for this game + player combination
    final existingRowIndex = await _findGameRosterRow(roster.gameId, roster.playerId);
    
    final List<Object> values = [
      roster.gameId,
      roster.playerId,
      roster.status,
    ];

    final Map<String, dynamic> body = {
      'values': [values],
      'majorDimension': 'ROWS',
    };

    Map<String, dynamic>? result;
    
    if (existingRowIndex != -1) {
      // Update existing row
      result = await _makeRequest(
        'POST',
        'values/GameRoster!A$existingRowIndex:C$existingRowIndex?valueInputOption=USER_ENTERED',
        body: body,
      );
      print('Updated existing roster entry at row $existingRowIndex for player ${roster.playerId} in game ${roster.gameId}');
    } else {
      // Append new row
      result = await _makeRequest(
        'POST',
        'values/GameRoster!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
        body: body,
      );
      print('Created new roster entry for player ${roster.playerId} in game ${roster.gameId}');
    }

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
      // Check authentication before each sync attempt
      bool isStillAuthenticated = await ensureAuthenticated();
      if (!isStillAuthenticated) {
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

  /// Syncs pending roster entries in the background without blocking the UI.
  /// This method implements retry logic and better error handling.
  Future<Map<String, int>> syncPendingRosterInBackground() async {
    print('Starting background roster sync...');
    
    try {
      bool isAuthenticated = await ensureAuthenticated();
      if (!isAuthenticated) {
        print('Background roster sync: Authentication failed.');
        return {'success': 0, 'failed': 0, 'pending': -1};
      }

      final gameRosterBox = Hive.box<GameRoster>('gameRoster');
      final pendingRoster = gameRosterBox.values.where((roster) => !roster.isSynced).toList();

      if (pendingRoster.isEmpty) {
        print('Background roster sync: No pending roster entries to sync.');
        return {'success': 0, 'failed': 0, 'pending': 0};
      }

      print('Background roster sync: Found ${pendingRoster.length} pending roster entries to sync.');
      
      // Use batch operations for better performance
      return await _syncRosterBatch(pendingRoster);
      
    } catch (e) {
      print('Background roster sync error: $e');
      return {'success': 0, 'failed': 0, 'pending': -1};
    }
  }

  /// Syncs a batch of roster entries with retry logic and better error handling.
  Future<Map<String, int>> _syncRosterBatch(List<GameRoster> rosterEntries) async {
    int successCount = 0;
    int failureCount = 0;
    const int maxRetries = 3;
    int consecutiveFailures = 0;
    const int circuitBreakerThreshold = 5; // Stop after 5 consecutive failures

    for (final roster in rosterEntries) {
      // Circuit breaker: stop if too many consecutive failures
      if (consecutiveFailures >= circuitBreakerThreshold) {
        print('Circuit breaker activated: Too many consecutive failures. Stopping batch sync.');
        failureCount += rosterEntries.length - successCount - failureCount;
        break;
      }

      bool success = false;
      int retryCount = 0;

      while (!success && retryCount < maxRetries) {
        try {
          // Check authentication before each sync attempt
          bool isStillAuthenticated = await ensureAuthenticated();
          if (!isStillAuthenticated) {
            print('Authentication lost during batch sync.');
            failureCount = rosterEntries.length - successCount;
            break;
          }

          success = await _syncGameRosterWithRetry(roster);
          
          if (success) {
            successCount++;
            consecutiveFailures = 0; // Reset consecutive failures on success
            print('Successfully synced roster entry for player ${roster.playerId} in game ${roster.gameId}');
          } else {
            retryCount++;
            if (retryCount < maxRetries) {
              // Exponential backoff: 2^retryCount seconds
              final backoffDelay = Duration(seconds: (2 * retryCount).clamp(1, 10));
              print('Retry $retryCount for roster entry ${roster.id} after ${backoffDelay.inSeconds}s delay...');
              await Future.delayed(backoffDelay);
            }
          }
        } catch (e) {
          retryCount++;
          print('Error syncing roster entry ${roster.id} (attempt $retryCount): $e');
          
          if (retryCount < maxRetries) {
            // Exponential backoff: 2^retryCount seconds
            final backoffDelay = Duration(seconds: (2 * retryCount).clamp(1, 10));
            await Future.delayed(backoffDelay);
          }
        }
      }

      if (!success) {
        failureCount++;
        consecutiveFailures++;
        print('Failed to sync roster entry ${roster.id} after $maxRetries attempts');
      }
    }

    print('Background roster sync complete. Success: $successCount, Failed: $failureCount');
    return {'success': successCount, 'failed': failureCount, 'pending': failureCount};
  }

  /// Syncs a single roster entry with improved error handling.
  Future<bool> _syncGameRosterWithRetry(GameRoster roster) async {
    try {
      // Check if a row already exists for this game + player combination
      final existingRowIndex = await _findGameRosterRow(roster.gameId, roster.playerId);
      
      final List<Object> values = [
        roster.gameId,
        roster.playerId,
        roster.status,
      ];

      final Map<String, dynamic> body = {
        'values': [values],
        'majorDimension': 'ROWS',
      };

      Map<String, dynamic>? result;
      
      if (existingRowIndex != -1) {
        // Update existing row
        result = await _makeRequest(
          'POST',
          'values/GameRoster!A$existingRowIndex:C$existingRowIndex?valueInputOption=USER_ENTERED',
          body: body,
        );
        print('Updated existing roster entry at row $existingRowIndex for player ${roster.playerId} in game ${roster.gameId}');
      } else {
        // Append new row
        result = await _makeRequest(
          'POST',
          'values/GameRoster!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
          body: body,
        );
        print('Created new roster entry for player ${roster.playerId} in game ${roster.gameId}');
      }

      if (result != null) {
        if (roster.isInBox) {
          roster.isSynced = true;
          await roster.save();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error in _syncGameRosterWithRetry: $e');
      return false;
    }
  }

  Future<bool> updateEventInSheet(GameEvent event) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot update event: Authentication failed.');
      return false;
    }

    // First get all IDs to find the row
    final idResult = await _makeRequest('GET', 'values/Events!A:A');
    if (idResult == null) {
      print('Failed to get event IDs from Google Sheets');
      return false;
    }

    final List<List<dynamic>> idValues = List<List<dynamic>>.from(idResult['values'] ?? []);
    
    int rowIndex = -1;
    for (int i = 0; i < idValues.length; i++) {
      if (idValues[i].isNotEmpty) {
        String sheetId = idValues[i][0].toString().trim();
        if (sheetId == event.id) {
          rowIndex = i + 1;
          break;
        }
      }
    }

    if (rowIndex == -1) {
      print('Event ID ${event.id} not found in the sheet. Cannot update.');
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
      _goalSituationToString(event.goalSituation),
      event.penaltyType ?? '',
      event.penaltyDuration ?? 0,
      event.yourTeamPlayersOnIce?.join(',') ?? '',
      event.goalieOnIceId ?? '',
    ];

    final Map<String, dynamic> body = {
      'values': [values],
      'majorDimension': 'ROWS',
    };

    final result = await _makeRequest(
      'PUT',
      'values/Events!A$rowIndex:O$rowIndex?valueInputOption=USER_ENTERED',
      body: body,
    );

    if (result != null) {
      print('Successfully updated event ${event.id} in row $rowIndex');
      if (event.isInBox) {
        event.isSynced = true;
        await event.save();
      }
      return true;
    } else {
      print('Failed to update event ${event.id} in Google Sheets');
      return false;
    }
  }

  /// Deletes an event from Google Sheets by finding and removing the row containing the event ID.
  ///
  /// @param eventId The ID of the event to delete from Google Sheets
  /// @return A Future that resolves to true if the deletion was successful, false otherwise
  Future<bool> deleteEventFromSheet(String eventId) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot delete event: Authentication failed.');
      return false;
    }

    try {
      // First get the correct sheet ID for the Events sheet
      final eventsSheetId = await _getSheetId('Events');
      if (eventsSheetId == null) {
        print('Failed to get Events sheet ID');
        return false;
      }

      // Get all IDs to find the row
      final idResult = await _makeRequest('GET', 'values/Events!A:A');
      if (idResult == null) {
        print('Failed to get event IDs from Google Sheets');
        return false;
      }

      final List<List<dynamic>> idValues = List<List<dynamic>>.from(idResult['values'] ?? []);
      
      int rowIndex = -1;
      for (int i = 0; i < idValues.length; i++) {
        if (idValues[i].isNotEmpty) {
          String sheetId = idValues[i][0].toString().trim();
          if (sheetId == eventId) {
            rowIndex = i + 1; // Google Sheets uses 1-based indexing
            break;
          }
        }
      }

      if (rowIndex == -1) {
        print('Event ID $eventId not found in the sheet. Cannot delete.');
        return false;
      }

      print('Found event $eventId at row $rowIndex, attempting to delete from sheet ID $eventsSheetId');

      // Use the batchUpdate API to delete the row
      final Map<String, dynamic> deleteRequest = {
        'requests': [
          {
            'deleteDimension': {
              'range': {
                'sheetId': eventsSheetId,
                'dimension': 'ROWS',
                'startIndex': rowIndex - 1, // Convert to 0-based indexing
                'endIndex': rowIndex
              }
            }
          }
        ]
      };

      // Make the batch update request
      final serviceAuth = await ServiceAccountAuth.instance;
      final Uri uri = Uri.parse('$_sheetsApiBase/$_spreadsheetId:batchUpdate');
      
      final response = await serviceAuth.makeAuthenticatedRequest(
        uri,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: json.encode(deleteRequest),
      );

      if (response.statusCode == 200) {
        print('Delete request completed with status 200');
        
        // Verify deletion by checking if the event ID still exists
        final verificationResult = await _makeRequest('GET', 'values/Events!A:A');
        if (verificationResult != null) {
          final List<List<dynamic>> verificationValues = List<List<dynamic>>.from(verificationResult['values'] ?? []);
          bool eventStillExists = false;
          
          for (var row in verificationValues) {
            if (row.isNotEmpty && row[0].toString().trim() == eventId) {
              eventStillExists = true;
              break;
            }
          }
          
          if (!eventStillExists) {
            print('Successfully deleted event $eventId from row $rowIndex in Google Sheets (verified)');
            return true;
          } else {
            print('Delete request returned success but event $eventId still exists in the sheet');
            return false;
          }
        } else {
          print('Could not verify deletion, but delete request returned success');
          return true; // Assume success if we can't verify
        }
      } else {
        print('Failed to delete event $eventId from Google Sheets. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting event $eventId from Google Sheets: $e');
      return false;
    }
  }

  /// Gets the sheet ID for a given sheet name.
  ///
  /// @param sheetName The name of the sheet to get the ID for
  /// @return The sheet ID if found, null otherwise
  Future<int?> _getSheetId(String sheetName) async {
    try {
      final serviceAuth = await ServiceAccountAuth.instance;
      final Uri uri = Uri.parse('$_sheetsApiBase/$_spreadsheetId');
      
      final response = await serviceAuth.makeAuthenticatedRequest(
        uri,
        method: 'GET',
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sheets = data['sheets'] as List<dynamic>?;
        
        if (sheets != null) {
          for (var sheet in sheets) {
            final properties = sheet['properties'];
            if (properties != null && properties['title'] == sheetName) {
              final sheetId = properties['sheetId'] as int?;
              print('Found sheet "$sheetName" with ID: $sheetId');
              return sheetId;
            }
          }
        }
        
        print('Sheet "$sheetName" not found in spreadsheet');
        return null;
      } else {
        print('Failed to get spreadsheet metadata. Status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting sheet ID for "$sheetName": $e');
      return null;
    }
  }

  String _goalSituationToString(GoalSituation? goalSituation) {
    if (goalSituation == null) return '';
    switch (goalSituation) {
      case GoalSituation.evenStrength:
        return 'Even Strength';
      case GoalSituation.powerPlay:
        return 'Power Play';
      case GoalSituation.shortHanded:
        return 'Short Handed';
    }
  }

  GoalSituation? _stringToGoalSituation(String? situationString) {
    if (situationString == null || situationString.isEmpty) return null;
    switch (situationString.toLowerCase()) {
      case 'even strength':
        return GoalSituation.evenStrength;
      case 'power play':
        return GoalSituation.powerPlay;
      case 'short handed':
        return GoalSituation.shortHanded;
      default:
        return null;
    }
  }

  /// Helper method to find an existing row in the GameRoster sheet for a specific game + player combination.
  /// 
  /// @param gameId The game ID to search for
  /// @param playerId The player ID to search for
  /// @return The row index (1-based) if found, -1 if not found
  Future<int> _findGameRosterRow(String gameId, String playerId) async {
    try {
      final result = await _makeRequest('GET', 'values/GameRoster!A:C');
      if (result == null) return -1;

      final List<List<dynamic>> values = List<List<dynamic>>.from(result['values'] ?? []);
      
      // Search through all rows to find matching gameId + playerId combination
      for (int i = 0; i < values.length; i++) {
        final row = values[i];
        if (row.length >= 2) {
          final rowGameId = row[0]?.toString() ?? '';
          final rowPlayerId = row[1]?.toString() ?? '';
          
          if (rowGameId == gameId && rowPlayerId == playerId) {
            // Return 1-based row index for Google Sheets API
            return i + 1;
          }
        }
      }
      
      return -1; // Not found
    } catch (e) {
      print('Error finding GameRoster row: $e');
      return -1;
    }
  }

  Future<bool> ensureAuthenticated() async {
    await _initialize();
    
    // Use cached authentication status if recent
    if (_isAuthenticated && _lastAuthCheck != null) {
      final age = DateTime.now().difference(_lastAuthCheck!);
      if (age < _authCacheValidDuration) {
        return true;
      }
    }
    
    // Perform actual authentication check
    try {
      final serviceAuth = await ServiceAccountAuth.instance;
      _isAuthenticated = serviceAuth.isAuthenticated;
      _lastAuthCheck = DateTime.now();
      return _isAuthenticated;
    } catch (e) {
      print('Error checking authentication: $e');
      _isAuthenticated = false;
      return false;
    }
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
      // Check authentication before each sync attempt
      bool isStillAuthenticated = await ensureAuthenticated();
      if (!isStillAuthenticated) {
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

  /// Syncs pending events in the background without blocking the UI.
  /// This method implements retry logic and better error handling for events.
  Future<Map<String, int>> syncPendingEventsInBackground() async {
    print('Starting background events sync...');
    
    try {
      bool isAuthenticated = await ensureAuthenticated();
      if (!isAuthenticated) {
        print('Background events sync: Authentication failed.');
        return {'success': 0, 'failed': 0, 'pending': -1};
      }

      final gameEventsBox = Hive.box<GameEvent>('gameEvents');
      final pendingEvents = gameEventsBox.values.where((event) => !event.isSynced).toList();

      if (pendingEvents.isEmpty) {
        print('Background events sync: No pending events to sync.');
        return {'success': 0, 'failed': 0, 'pending': 0};
      }

      print('Background events sync: Found ${pendingEvents.length} pending events to sync.');
      
      // Use batch operations for better performance
      return await _syncEventsBatch(pendingEvents);
      
    } catch (e) {
      print('Background events sync error: $e');
      return {'success': 0, 'failed': 0, 'pending': -1};
    }
  }

  /// Syncs a batch of events with retry logic and better error handling.
  Future<Map<String, int>> _syncEventsBatch(List<GameEvent> events) async {
    int successCount = 0;
    int failureCount = 0;
    const int maxRetries = 3;
    int consecutiveFailures = 0;
    const int circuitBreakerThreshold = 5; // Stop after 5 consecutive failures

    for (final event in events) {
      // Circuit breaker: stop if too many consecutive failures
      if (consecutiveFailures >= circuitBreakerThreshold) {
        print('Circuit breaker activated: Too many consecutive failures. Stopping batch sync.');
        failureCount += events.length - successCount - failureCount;
        break;
      }

      bool success = false;
      int retryCount = 0;

      while (!success && retryCount < maxRetries) {
        try {
          // Check authentication before each sync attempt
          bool isStillAuthenticated = await ensureAuthenticated();
          if (!isStillAuthenticated) {
            print('Authentication lost during batch sync.');
            failureCount = events.length - successCount;
            break;
          }

          success = await _syncGameEventWithRetry(event);
          
          if (success) {
            successCount++;
            consecutiveFailures = 0; // Reset consecutive failures on success
            print('Successfully synced event ${event.id}');
          } else {
            retryCount++;
            if (retryCount < maxRetries) {
              // Exponential backoff: 2^retryCount seconds, capped at 10 seconds
              final backoffDelay = Duration(seconds: (2 * retryCount).clamp(1, 10));
              print('Retry $retryCount for event ${event.id} after ${backoffDelay.inSeconds}s delay...');
              await Future.delayed(backoffDelay);
            }
          }
        } catch (e) {
          retryCount++;
          print('Error syncing event ${event.id} (attempt $retryCount): $e');
          
          if (retryCount < maxRetries) {
            // Exponential backoff: 2^retryCount seconds, capped at 10 seconds
            final backoffDelay = Duration(seconds: (2 * retryCount).clamp(1, 10));
            await Future.delayed(backoffDelay);
          }
        }
      }

      if (!success) {
        failureCount++;
        consecutiveFailures++;
        print('Failed to sync event ${event.id} after $maxRetries attempts');
      }
    }

    print('Background events sync complete. Success: $successCount, Failed: $failureCount');
    return {'success': successCount, 'failed': failureCount, 'pending': failureCount};
  }

  /// Syncs a single event with improved error handling.
  Future<bool> _syncGameEventWithRetry(GameEvent event) async {
    try {
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
        _goalSituationToString(event.goalSituation),
        event.penaltyType ?? '',
        event.penaltyDuration ?? 0,
        event.yourTeamPlayersOnIce?.join(',') ?? '',
        event.goalieOnIceId ?? '',
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
        if (event.isInBox) {
          event.isSynced = true;
          await event.save();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error in _syncGameEventWithRetry: $e');
      return false;
    }
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

    final result = await _makeRequest('GET', 'values/Games!A2:F');
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
          String gameType = row.length > 5 ? row[5]?.toString() ?? 'R' : 'R'; // Default to 'R' (Regular Season) if not specified
          
          if (id.isNotEmpty && opponent.isNotEmpty) {
            games.add(Game(
              id: id,
              date: date,
              opponent: opponent,
              location: location,
              teamId: teamId,
              gameType: gameType,
            ));
            print('Parsed game: $opponent on ${date.toIso8601String().split('T')[0]} (ID: $id, Type: $gameType)');
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

    final result = await _makeRequest('GET', 'values/Events!A2:O');
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
          
          GoalSituation? goalSituation = row.length > 10 ? _stringToGoalSituation(row[10]?.toString()) : null;
          
          String? penaltyType = row.length > 11 ? row[11]?.toString() : null;
          if (penaltyType?.isEmpty ?? true) penaltyType = null;
          
          int? penaltyDuration = row.length > 12 ? int.tryParse(row[12]?.toString() ?? '') : null;
          
          List<String>? playersOnIce = row.length > 13 && row[13]?.toString().isNotEmpty == true 
              ? row[13].toString().split(',')
              : null;

          String? goalieOnIceId = row.length > 14 ? row[14]?.toString() : null;
          if (goalieOnIceId?.isEmpty ?? true) goalieOnIceId = null;

          // Allow events with valid ID and gameId, regardless of primaryPlayerId
          // This ensures all shot events are imported, even if they don't have a specific player assigned
          if (id.isNotEmpty && gameId.isNotEmpty && eventType.isNotEmpty) {
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
              goalSituation: goalSituation,
              goalieOnIceId: goalieOnIceId,
            ));
            print('Parsed event: ${eventType} for ${team} (ID: $id, IsGoal: $isGoal)');
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
          // Check if event already exists in Google Sheets
          if (remoteEventIds.contains(event.id)) {
            // Event exists in Google Sheets, just mark as synced locally
            print('Event ${event.id} already exists in Google Sheets, marking as synced');
            event.isSynced = true;
            await event.save();
          } else {
            // Event doesn't exist in Google Sheets, sync it
            bool syncSuccess = await syncGameEvent(event);
            if (syncSuccess) {
              print('Successfully synced event ${event.id}');
              event.isSynced = true;
              await event.save();
            } else {
              print('Failed to sync event ${event.id}');
            }
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
