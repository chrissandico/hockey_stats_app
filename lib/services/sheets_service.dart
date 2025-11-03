import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:hockey_stats_app/services/service_account_auth.dart';
import 'package:hockey_stats_app/services/connectivity_service.dart';
import 'package:hockey_stats_app/utils/sync_error_utils.dart';

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
        // Analyze the error using the new error categorization system
        final errorInfo = SyncErrorUtils.analyzeError('HTTP ${response.statusCode}', response: response);
        
        // Log detailed error information
        print('SheetsService API Error:');
        print('  Status: ${response.statusCode}');
        print('  Category: ${SyncErrorUtils.getCategoryStatusMessage(errorInfo.category)}');
        print('  User Message: ${errorInfo.userMessage}');
        print('  Technical: ${errorInfo.technicalMessage}');
        if (errorInfo.suggestedAction != null) {
          print('  Suggested Action: ${errorInfo.suggestedAction}');
        }
        print('  Retryable: ${errorInfo.isRetryable}');
        
        // Store error information for potential UI display (without blocking)
        _storeLastSyncError(errorInfo);
        
        return null;
      }
    } catch (e) {
      // Analyze the exception using the new error categorization system
      final errorInfo = SyncErrorUtils.analyzeError(e);
      
      // Log detailed error information
      print('SheetsService Request Error:');
      print('  Category: ${SyncErrorUtils.getCategoryStatusMessage(errorInfo.category)}');
      print('  User Message: ${errorInfo.userMessage}');
      print('  Technical: ${errorInfo.technicalMessage}');
      if (errorInfo.suggestedAction != null) {
        print('  Suggested Action: ${errorInfo.suggestedAction}');
      }
      print('  Retryable: ${errorInfo.isRetryable}');
      
      // Store error information for potential UI display (without blocking)
      _storeLastSyncError(errorInfo);
      
      return null;
    }
  }
  
  /// Store the last sync error for potential UI display (non-blocking)
  void _storeLastSyncError(SyncErrorInfo errorInfo) {
    try {
      // Store error in a simple way that doesn't block the sync operation
      // This could be expanded to use a proper error storage mechanism
      print('Storing sync error for UI: ${errorInfo.userMessage}');
      
      // For now, we'll just ensure the error is logged in a structured way
      // Future enhancement: Store in Hive box for UI display
    } catch (e) {
      // Don't let error storage block the main sync operation
      print('Failed to store sync error: $e');
    }
  }

  Future<bool> syncGameEvent(GameEvent event) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync event: Authentication failed.');
      return false;
    }

    // Check if event already exists in Google Sheets to prevent duplicates
    final existingRowIndex = await _findEventRow(event.id);
    
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

    Map<String, dynamic>? result;
    
    if (existingRowIndex != -1) {
      // Event already exists, update the existing row instead of creating duplicate
      print('Event ${event.id} already exists at row $existingRowIndex, updating instead of creating duplicate');
      result = await _makeRequest(
        'PUT',
        'values/Events!A$existingRowIndex:O$existingRowIndex?valueInputOption=USER_ENTERED',
        body: body,
      );
      print('Updated existing event ${event.id} at row $existingRowIndex');
    } else {
      // Event doesn't exist, append new row
      result = await _makeRequest(
        'POST',
        'values/Events!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
        body: body,
      );
      print('Created new event ${event.id}');
    }

    if (result != null) {
      print('Successfully synced event ${event.id}');
      // Immediately update the sync status to prevent race conditions
      if (event.isInBox) {
        event.isSynced = true;
        await event.save();
      }
      return true;
    } else {
      print('Failed to sync event ${event.id}');
      return false;
    }
  }

  /// Syncs a single Game to Google Sheets
  /// Creates a new row if the game doesn't exist, updates if it does
  Future<bool> syncGame(Game game) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync game: Authentication failed.');
      return false;
    }

    // Check if game already exists in Google Sheets
    final existingRowIndex = await _findGameRow(game.id);
    
    // Format the date as YYYY-MM-DD
    String formattedDate = "${game.date.year}-${game.date.month.toString().padLeft(2, '0')}-${game.date.day.toString().padLeft(2, '0')}";

    final List<Object> values = [
      game.id,
      formattedDate,
      game.opponent,
      game.location ?? '',
      game.teamId,
      game.gameType,
    ];

    final Map<String, dynamic> body = {
      'values': [values],
      'majorDimension': 'ROWS',
    };

    Map<String, dynamic>? result;
    
    if (existingRowIndex != -1) {
      // Game already exists, update the existing row
      print('Game ${game.id} already exists at row $existingRowIndex, updating');
      result = await _makeRequest(
        'PUT',
        'values/Games!A$existingRowIndex:F$existingRowIndex?valueInputOption=USER_ENTERED',
        body: body,
      );
      print('Updated existing game ${game.id} at row $existingRowIndex');
    } else {
      // Game doesn't exist, append new row
      result = await _makeRequest(
        'POST',
        'values/Games!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
        body: body,
      );
      print('Created new game ${game.id}');
    }

    if (result != null) {
      print('Successfully synced game ${game.id} to Google Sheets');
      return true;
    } else {
      print('Failed to sync game ${game.id} to Google Sheets');
      return false;
    }
  }

  /// Helper method to find an existing game row in Google Sheets by game ID
  Future<int> _findGameRow(String gameId) async {
    try {
      final result = await _makeRequest('GET', 'values/Games!A:A');
      if (result == null) return -1;

      final List<List<dynamic>> values = List<List<dynamic>>.from(result['values'] ?? []);
      
      // Search through all rows to find matching game ID
      for (int i = 0; i < values.length; i++) {
        final row = values[i];
        if (row.isNotEmpty) {
          final rowGameId = row[0]?.toString() ?? '';
          
          if (rowGameId == gameId) {
            // Return 1-based row index for Google Sheets API
            return i + 1;
          }
        }
      }
      
      return -1; // Not found
    } catch (e) {
      print('Error finding Game row: $e');
      return -1;
    }
  }

  /// Deletes a game from Google Sheets by game ID
  Future<bool> deleteGame(String gameId) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot delete game: Authentication failed.');
      return false;
    }

    // Find the game row
    final rowIndex = await _findGameRow(gameId);
    if (rowIndex == -1) {
      print('Game $gameId not found in Google Sheets');
      return false; // Game doesn't exist, consider it a success
    }

    try {
      // Get the Games sheet ID
      final gamesSheetId = await _getSheetId('Games');
      if (gamesSheetId == null) {
        print('Could not find Games sheet ID');
        return false;
      }

      // Delete the row using batchUpdate
      final Map<String, dynamic> body = {
        'requests': [
          {
            'deleteDimension': {
              'range': {
                'sheetId': gamesSheetId,
                'dimension': 'ROWS',
                'startIndex': rowIndex - 1, // Convert to 0-based indexing
                'endIndex': rowIndex, // Exclusive end
              }
            }
          }
        ]
      };

      final result = await _makeRequest('POST', ':batchUpdate', body: body);
      
      if (result != null) {
        print('Successfully deleted game $gameId from Google Sheets');
        return true;
      } else {
        print('Failed to delete game $gameId from Google Sheets');
        return false;
      }
    } catch (e) {
      print('Error deleting game from Google Sheets: $e');
      return false;
    }
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

  /// Helper method to find an existing row in the Events sheet for a specific event ID.
  /// 
  /// @param eventId The event ID to search for
  /// @return The row index (1-based) if found, -1 if not found
  Future<int> _findEventRow(String eventId) async {
    try {
      final result = await _makeRequest('GET', 'values/Events!A:A');
      if (result == null) return -1;

      final List<List<dynamic>> values = List<List<dynamic>>.from(result['values'] ?? []);
      
      // Search through all rows to find matching event ID
      for (int i = 0; i < values.length; i++) {
        final row = values[i];
        if (row.isNotEmpty) {
          final rowEventId = row[0]?.toString() ?? '';
          
          if (rowEventId == eventId) {
            // Return 1-based row index for Google Sheets API
            return i + 1;
          }
        }
      }
      
      return -1; // Not found
    } catch (e) {
      print('Error finding Event row: $e');
      return -1;
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
    
    // Check connectivity first - skip authentication if offline
    final connectivityService = ConnectivityService();
    
    // Force a connectivity check if the service hasn't been checked recently
    final detailedStatus = connectivityService.getDetailedStatus();
    if (detailedStatus['lastCheck'] == null) {
      print('SheetsService: No recent connectivity check found, forcing check...');
      connectivityService.forceCheck();
      // Wait longer for the check to complete
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    
    final shouldAttempt = connectivityService.shouldAttemptNetworkOperation();
    print('SheetsService: Connectivity check result - shouldAttempt: $shouldAttempt');
    print('SheetsService: Detailed status: ${connectivityService.getDetailedStatus()}');
    
    // If connectivity service says offline but we know network is working, 
    // let's try a direct check using the same method as NetworkUtils
    if (!shouldAttempt) {
      print('SheetsService: Connectivity service reports offline, performing direct check...');
      try {
        // Try a direct connectivity check similar to NetworkUtils
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          print('SheetsService: Direct connectivity check passed, proceeding with authentication');
          // Don't return false, continue with authentication
        } else {
          print('SheetsService: Direct connectivity check failed, skipping authentication');
          return false;
        }
      } catch (e) {
        print('SheetsService: Direct connectivity check error: $e, skipping authentication');
        return false;
      }
    }
    
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

      // Get user preferences
      final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
      final prefs = prefsBox.get('user_prefs') ?? SyncPreferences();

      final gameEventsBox = Hive.box<GameEvent>('gameEvents');
      final allPendingEvents = gameEventsBox.values.where((event) => !event.isSynced).toList();

      // Filter events based on user preferences
      final pendingEvents = allPendingEvents.where((event) => prefs.shouldSyncEvent(event)).toList();
      final skippedCount = allPendingEvents.length - pendingEvents.length;

      if (skippedCount > 0) {
        print('Background events sync: Skipped $skippedCount events based on user preferences');
      }

      if (pendingEvents.isEmpty) {
        print('Background events sync: No events to sync after applying preferences.');
        return {'success': 0, 'failed': 0, 'pending': 0};
      }

      print('Background events sync: Found ${pendingEvents.length} events to sync (${allPendingEvents.length} total pending).');
      
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

  /// Syncs a single event with improved error handling and deduplication.
  Future<bool> _syncGameEventWithRetry(GameEvent event) async {
    try {
      // Check if event already exists in Google Sheets to prevent duplicates
      final existingRowIndex = await _findEventRow(event.id);
      
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

      Map<String, dynamic>? result;
      
      if (existingRowIndex != -1) {
        // Event already exists, update the existing row instead of creating duplicate
        print('_syncGameEventWithRetry: Event ${event.id} already exists at row $existingRowIndex, updating instead of creating duplicate');
        result = await _makeRequest(
          'PUT',
          'values/Events!A$existingRowIndex:O$existingRowIndex?valueInputOption=USER_ENTERED',
          body: body,
        );
        print('_syncGameEventWithRetry: Updated existing event ${event.id} at row $existingRowIndex');
      } else {
        // Event doesn't exist, append new row
        result = await _makeRequest(
          'POST',
          'values/Events!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
          body: body,
        );
        print('_syncGameEventWithRetry: Created new event ${event.id}');
      }

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

  /// Sync pending attendance records in background
  Future<Map<String, int>> syncPendingAttendanceInBackground() async {
    print('SheetsService: Starting background attendance sync...');
    
    try {
      // Check user preferences first
      final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
      final prefs = prefsBox.get('user_prefs') ?? SyncPreferences();
      
      if (!prefs.shouldSyncAttendance()) {
        print('SheetsService: Attendance sync disabled by user preferences');
        return {'success': 0, 'failed': 0, 'pending': 0};
      }
      
      final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
      final pendingAttendance = attendanceBox.values
          .where((attendance) => !attendance.isSynced)
          .toList();

      if (pendingAttendance.isEmpty) {
        print('SheetsService: No pending attendance records to sync');
        return {'success': 0, 'failed': 0, 'pending': 0};
      }

      print('SheetsService: Found ${pendingAttendance.length} pending attendance records');

      int successCount = 0;
      int failureCount = 0;

      for (final attendance in pendingAttendance) {
        try {
          final success = await syncGameAttendance(attendance);
          if (success) {
            successCount++;
          } else {
            failureCount++;
          }
        } catch (e) {
          print('SheetsService: Error syncing attendance ${attendance.id}: $e');
          failureCount++;
        }

        // Small delay between requests to avoid overwhelming the API
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final remainingPending = attendanceBox.values
          .where((attendance) => !attendance.isSynced)
          .length;

      print('Background attendance sync complete. Success: $successCount, Failed: $failureCount');
      return {
        'success': successCount,
        'failed': failureCount,
        'pending': remainingPending,
      };
    } catch (e) {
      print('SheetsService: Error in background attendance sync: $e');
      return {'success': 0, 'failed': 0, 'pending': -1};
    }
  }

  /// Sync pending events for a specific game with preference filtering
  Future<Map<String, int>> syncPendingEventsForGame(String? gameId) async {
    print('SheetsService: Starting game-specific events sync for game: $gameId');
    
    try {
      bool isAuthenticated = await ensureAuthenticated();
      if (!isAuthenticated) {
        print('Game-specific events sync: Authentication failed.');
        return {'success': 0, 'failed': 0, 'pending': -1};
      }

      // Get user preferences
      final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
      final prefs = prefsBox.get('user_prefs') ?? SyncPreferences();

      final gameEventsBox = Hive.box<GameEvent>('gameEvents');
      
      // Filter by game ID first, then by sync status
      var gameEvents = gameEventsBox.values.where((event) => !event.isSynced);
      
      if (gameId != null) {
        gameEvents = gameEvents.where((event) => event.gameId == gameId);
      }
      
      final allPendingEvents = gameEvents.toList();

      // Filter events based on user preferences
      final pendingEvents = allPendingEvents.where((event) => prefs.shouldSyncEvent(event)).toList();
      final skippedCount = allPendingEvents.length - pendingEvents.length;

      print('Game-specific events sync: Found ${allPendingEvents.length} unsynced events for game $gameId');
      if (skippedCount > 0) {
        print('Game-specific events sync: Skipped $skippedCount events based on user preferences');
      }

      if (pendingEvents.isEmpty) {
        print('Game-specific events sync: No events to sync after applying preferences.');
        return {'success': 0, 'failed': 0, 'pending': 0};
      }

      print('Game-specific events sync: Syncing ${pendingEvents.length} events for game $gameId');
      
      // Use batch operations for better performance
      return await _syncEventsBatch(pendingEvents);
      
    } catch (e) {
      print('Game-specific events sync error: $e');
      return {'success': 0, 'failed': 0, 'pending': -1};
    }
  }

  /// Sync pending attendance for a specific game
  Future<Map<String, int>> syncPendingAttendanceForGame(String? gameId) async {
    print('SheetsService: Starting game-specific attendance sync for game: $gameId');
    
    try {
      // Check user preferences first
      final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
      final prefs = prefsBox.get('user_prefs') ?? SyncPreferences();
      
      if (!prefs.shouldSyncAttendance()) {
        print('SheetsService: Attendance sync disabled by user preferences');
        return {'success': 0, 'failed': 0, 'pending': 0};
      }
      
      final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
      
      // Filter by game ID first, then by sync status
      var attendanceRecords = attendanceBox.values.where((attendance) => !attendance.isSynced);
      
      if (gameId != null) {
        attendanceRecords = attendanceRecords.where((attendance) => attendance.gameId == gameId);
      }
      
      final pendingAttendance = attendanceRecords.toList();

      print('Game-specific attendance sync: Found ${pendingAttendance.length} unsynced attendance records for game $gameId');

      if (pendingAttendance.isEmpty) {
        print('SheetsService: No pending attendance records to sync for game $gameId');
        return {'success': 0, 'failed': 0, 'pending': 0};
      }

      int successCount = 0;
      int failureCount = 0;

      for (final attendance in pendingAttendance) {
        try {
          final success = await syncGameAttendance(attendance);
          if (success) {
            successCount++;
          } else {
            failureCount++;
          }
        } catch (e) {
          print('SheetsService: Error syncing attendance ${attendance.id}: $e');
          failureCount++;
        }

        // Small delay between requests to avoid overwhelming the API
        await Future.delayed(const Duration(milliseconds: 200));
      }

      print('Game-specific attendance sync complete. Success: $successCount, Failed: $failureCount');
      return {
        'success': successCount,
        'failed': failureCount,
        'pending': failureCount,
      };
    } catch (e) {
      print('SheetsService: Error in game-specific attendance sync: $e');
      return {'success': 0, 'failed': 0, 'pending': -1};
    }
  }

  /// Sync a single GameAttendance record to Google Sheets
  /// This method now includes backward compatibility with GameRoster sheet
  Future<bool> syncGameAttendance(GameAttendance attendance) async {
    bool isAuthenticated = await ensureAuthenticated();
    if (!isAuthenticated) {
      print('Cannot sync attendance: Authentication failed.');
      return false;
    }

    try {
      // First, try to sync to GameAttendance sheet (new format)
      bool newFormatSuccess = await _syncToGameAttendanceSheet(attendance);
      
      // If that fails or doesn't exist, fall back to GameRoster sheet (backward compatibility)
      if (!newFormatSuccess) {
        print('GameAttendance sheet sync failed, falling back to GameRoster format');
        bool legacySuccess = await _syncToGameRosterSheet(attendance);
        
        if (legacySuccess) {
          print('Successfully synced attendance to GameRoster sheet (legacy format)');
          if (attendance.isInBox) {
            attendance.isSynced = true;
            await attendance.save();
          }
          return true;
        }
      } else {
        print('Successfully synced attendance to GameAttendance sheet (new format)');
        if (attendance.isInBox) {
          attendance.isSynced = true;
          await attendance.save();
        }
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error syncing attendance ${attendance.id}: $e');
      return false;
    }
  }

  /// Sync to the new GameAttendance sheet format
  Future<bool> _syncToGameAttendanceSheet(GameAttendance attendance) async {
    try {
      // Format the attendance data for GameAttendance sheet
      final List<Object> values = [
        attendance.gameId,
        attendance.teamId,
        attendance.absentPlayerIds.join(','),
        attendance.timestamp.toIso8601String(),
      ];

      final Map<String, dynamic> body = {
        'values': [values],
        'majorDimension': 'ROWS',
      };

      // Check if attendance record already exists for this game
      final existingRowIndex = await _findGameAttendanceRow(attendance.gameId, attendance.teamId);
      
      Map<String, dynamic>? result;
      
      if (existingRowIndex != -1) {
        // Update existing row
        result = await _makeRequest(
          'POST',
          'values/GameAttendance!A$existingRowIndex:D$existingRowIndex?valueInputOption=USER_ENTERED',
          body: body,
        );
        print('Updated existing attendance record at row $existingRowIndex for game ${attendance.gameId}');
      } else {
        // Append new row
        result = await _makeRequest(
          'POST',
          'values/GameAttendance!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
          body: body,
        );
        print('Created new attendance record for game ${attendance.gameId}');
      }

      return result != null;
    } catch (e) {
      print('Error syncing to GameAttendance sheet: $e');
      return false;
    }
  }

  /// Sync to the legacy GameRoster sheet format (backward compatibility)
  Future<bool> _syncToGameRosterSheet(GameAttendance attendance) async {
    try {
      // Get all players for the team to create individual roster entries
      final playersBox = Hive.box<Player>('players');
      final teamPlayers = playersBox.values
          .where((p) => p.teamId == attendance.teamId)
          .toList();

      if (teamPlayers.isEmpty) {
        print('No players found for team ${attendance.teamId}');
        return false;
      }

      print('Converting GameAttendance to GameRoster format for ${teamPlayers.length} players');

      // First, remove any existing GameRoster entries for this game
      await _clearGameRosterEntriesForGame(attendance.gameId);

      // Create individual GameRoster entries for each player
      List<List<Object>> rosterRows = [];
      
      for (final player in teamPlayers) {
        final status = attendance.absentPlayerIds.contains(player.id) ? 'Absent' : 'Present';
        rosterRows.add([
          attendance.gameId,
          player.id,
          status,
        ]);
      }

      // Batch insert all roster entries
      final Map<String, dynamic> body = {
        'values': rosterRows,
        'majorDimension': 'ROWS',
      };

      final result = await _makeRequest(
        'POST',
        'values/GameRoster!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
        body: body,
      );

      if (result != null) {
        print('Successfully created ${rosterRows.length} GameRoster entries for game ${attendance.gameId}');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error syncing to GameRoster sheet: $e');
      return false;
    }
  }

  /// Clear existing GameRoster entries for a specific game
  Future<void> _clearGameRosterEntriesForGame(String gameId) async {
    try {
      // Get all GameRoster data to find rows to delete
      final result = await _makeRequest('GET', 'values/GameRoster!A:C');
      if (result == null) return;

      final List<List<dynamic>> values = List<List<dynamic>>.from(result['values'] ?? []);
      
      // Find all rows that match this gameId (in reverse order for safe deletion)
      List<int> rowsToDelete = [];
      for (int i = values.length - 1; i >= 0; i--) {
        final row = values[i];
        if (row.isNotEmpty && row[0]?.toString() == gameId) {
          rowsToDelete.add(i + 1); // Convert to 1-based indexing
        }
      }

      if (rowsToDelete.isEmpty) {
        print('No existing GameRoster entries found for game $gameId');
        return;
      }

      print('Found ${rowsToDelete.length} existing GameRoster entries to clear for game $gameId');

      // Get the GameRoster sheet ID for batch deletion
      final gameRosterSheetId = await _getSheetId('GameRoster');
      if (gameRosterSheetId == null) {
        print('Could not find GameRoster sheet ID');
        return;
      }

      // Create batch delete requests (process in chunks to avoid API limits)
      const chunkSize = 10;
      for (int i = 0; i < rowsToDelete.length; i += chunkSize) {
        final chunk = rowsToDelete.skip(i).take(chunkSize).toList();
        
        final List<Map<String, dynamic>> deleteRequests = chunk.map((rowIndex) => {
          'deleteDimension': {
            'range': {
              'sheetId': gameRosterSheetId,
              'dimension': 'ROWS',
              'startIndex': rowIndex - 1, // Convert to 0-based indexing
              'endIndex': rowIndex
            }
          }
        }).toList();

        final Map<String, dynamic> batchRequest = {
          'requests': deleteRequests
        };

        // Execute batch delete
        final serviceAuth = await ServiceAccountAuth.instance;
        final Uri uri = Uri.parse('$_sheetsApiBase/$_spreadsheetId:batchUpdate');
        
        final response = await serviceAuth.makeAuthenticatedRequest(
          uri,
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: json.encode(batchRequest),
        );

        if (response.statusCode == 200) {
          print('Successfully deleted ${chunk.length} GameRoster entries');
        } else {
          print('Failed to delete GameRoster entries: ${response.statusCode}');
        }

        // Small delay between chunks to avoid rate limiting
        if (i + chunkSize < rowsToDelete.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      print('Error clearing GameRoster entries for game $gameId: $e');
    }
  }

  /// Helper method to find an existing row in the GameAttendance sheet for a specific game + team combination.
  Future<int> _findGameAttendanceRow(String gameId, String teamId) async {
    try {
      final result = await _makeRequest('GET', 'values/GameAttendance!A:B');
      if (result == null) return -1;

      final List<List<dynamic>> values = List<List<dynamic>>.from(result['values'] ?? []);
      
      // Search through all rows to find matching gameId + teamId combination
      for (int i = 0; i < values.length; i++) {
        final row = values[i];
        if (row.length >= 2) {
          final rowGameId = row[0]?.toString() ?? '';
          final rowTeamId = row[1]?.toString() ?? '';
          
          if (rowGameId == gameId && rowTeamId == teamId) {
            // Return 1-based row index for Google Sheets API
            return i + 1;
          }
        }
      }
      
      return -1; // Not found
    } catch (e) {
      print('Error finding GameAttendance row: $e');
      return -1;
    }
  }
}
