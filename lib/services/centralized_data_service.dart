import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:hive/hive.dart';

/// Centralized data service that ensures Google Sheets is always the source of truth
/// for all statistics calculations and data display.
class CentralizedDataService {
  static final CentralizedDataService _instance = CentralizedDataService._internal();
  factory CentralizedDataService() => _instance;
  CentralizedDataService._internal();

  final SheetsService _sheetsService = SheetsService();
  
  // Cache for fresh data to avoid repeated API calls within a short timeframe
  Map<String, List<GameEvent>>? _cachedEvents;
  DateTime? _lastEventsFetch;
  static const Duration _cacheValidDuration = Duration(minutes: 2);

  /// Gets the most current game events, prioritizing Google Sheets data
  /// Falls back to local data only if Google Sheets is unavailable
  Future<List<GameEvent>> getCurrentGameEvents(String gameId, {bool forceRefresh = false}) async {
    print('CentralizedDataService: Getting current events for game $gameId (forceRefresh: $forceRefresh)');
    
    // Check if we have valid cached data and don't need to force refresh
    if (!forceRefresh && 
        _cachedEvents != null && 
        _lastEventsFetch != null && 
        DateTime.now().difference(_lastEventsFetch!) < _cacheValidDuration) {
      final cachedGameEvents = _cachedEvents![gameId] ?? [];
      print('CentralizedDataService: Using cached data (${cachedGameEvents.length} events)');
      return cachedGameEvents;
    }

    try {
      // Try to get fresh data from Google Sheets
      print('CentralizedDataService: Fetching fresh data from Google Sheets...');
      final isAuthenticated = await _sheetsService.ensureAuthenticated();
      
      if (isAuthenticated) {
        final allEvents = await _sheetsService.fetchEvents();
        if (allEvents != null) {
          // Cache the fresh data
          _cachedEvents = <String, List<GameEvent>>{};
          for (final event in allEvents) {
            if (!_cachedEvents!.containsKey(event.gameId)) {
              _cachedEvents![event.gameId] = [];
            }
            _cachedEvents![event.gameId]!.add(event);
          }
          _lastEventsFetch = DateTime.now();
          
          final gameEvents = _cachedEvents![gameId] ?? [];
          print('CentralizedDataService: Fetched ${allEvents.length} total events from Google Sheets, ${gameEvents.length} for game $gameId');
          
          // Also update local cache for offline access
          await _updateLocalCache(allEvents);
          
          return gameEvents;
        }
      }
      
      print('CentralizedDataService: Google Sheets unavailable, falling back to local data');
    } catch (e) {
      print('CentralizedDataService: Error fetching from Google Sheets: $e');
    }

    // Fallback to local data
    return _getLocalGameEvents(gameId);
  }

  /// Gets all current game events from all games, prioritizing Google Sheets
  Future<List<GameEvent>> getAllCurrentGameEvents({bool forceRefresh = false}) async {
    print('CentralizedDataService: Getting all current events (forceRefresh: $forceRefresh)');
    
    // Check if we have valid cached data and don't need to force refresh
    if (!forceRefresh && 
        _cachedEvents != null && 
        _lastEventsFetch != null && 
        DateTime.now().difference(_lastEventsFetch!) < _cacheValidDuration) {
      final allCachedEvents = <GameEvent>[];
      _cachedEvents!.values.forEach((events) => allCachedEvents.addAll(events));
      print('CentralizedDataService: Using cached data (${allCachedEvents.length} total events)');
      return allCachedEvents;
    }

    try {
      // Try to get fresh data from Google Sheets
      print('CentralizedDataService: Fetching all fresh data from Google Sheets...');
      final isAuthenticated = await _sheetsService.ensureAuthenticated();
      
      if (isAuthenticated) {
        final allEvents = await _sheetsService.fetchEvents();
        if (allEvents != null) {
          // Cache the fresh data
          _cachedEvents = <String, List<GameEvent>>{};
          for (final event in allEvents) {
            if (!_cachedEvents!.containsKey(event.gameId)) {
              _cachedEvents![event.gameId] = [];
            }
            _cachedEvents![event.gameId]!.add(event);
          }
          _lastEventsFetch = DateTime.now();
          
          print('CentralizedDataService: Fetched ${allEvents.length} total events from Google Sheets');
          
          // Also update local cache for offline access
          await _updateLocalCache(allEvents);
          
          return allEvents;
        }
      }
      
      print('CentralizedDataService: Google Sheets unavailable, falling back to local data');
    } catch (e) {
      print('CentralizedDataService: Error fetching from Google Sheets: $e');
    }

    // Fallback to local data
    return _getAllLocalGameEvents();
  }

  /// Calculates the current score for a game using fresh Google Sheets data
  Future<Map<String, int>> calculateCurrentScore(String gameId, String teamId, {bool forceRefresh = false}) async {
    print('CentralizedDataService: Calculating current score for game $gameId, team $teamId');
    
    final events = await getCurrentGameEvents(gameId, forceRefresh: forceRefresh);
    
    int yourTeamScore = events.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.team == teamId
    ).length;

    int opponentScore = events.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.team == 'opponent'
    ).length;

    print('CentralizedDataService: Score calculation from ${events.length} events:');
    print('  Your Team ($teamId): $yourTeamScore goals');
    print('  Opponent: $opponentScore goals');

    return {
      'Your Team': yourTeamScore,
      'Opponent': opponentScore,
    };
  }

  /// Forces a refresh of all data from Google Sheets
  Future<bool> forceRefreshFromSheets() async {
    print('CentralizedDataService: Force refreshing all data from Google Sheets...');
    
    try {
      final result = await _sheetsService.syncDataFromSheets();
      if (result['success'] == true) {
        // Clear cache to force fresh fetch next time
        _cachedEvents = null;
        _lastEventsFetch = null;
        print('CentralizedDataService: Force refresh successful');
        return true;
      }
    } catch (e) {
      print('CentralizedDataService: Error during force refresh: $e');
    }
    
    return false;
  }

  /// Clears the cache to force fresh data fetch on next request
  void clearCache() {
    print('CentralizedDataService: Clearing cache');
    _cachedEvents = null;
    _lastEventsFetch = null;
  }

  /// Gets game events from local Hive storage (fallback)
  List<GameEvent> _getLocalGameEvents(String gameId) {
    try {
      final gameEventsBox = Hive.box<GameEvent>('gameEvents');
      final events = gameEventsBox.values.where((event) => event.gameId == gameId).toList();
      print('CentralizedDataService: Retrieved ${events.length} events from local storage for game $gameId');
      return events;
    } catch (e) {
      print('CentralizedDataService: Error getting local events: $e');
      return [];
    }
  }

  /// Gets all game events from local Hive storage (fallback)
  List<GameEvent> _getAllLocalGameEvents() {
    try {
      final gameEventsBox = Hive.box<GameEvent>('gameEvents');
      final events = gameEventsBox.values.toList();
      print('CentralizedDataService: Retrieved ${events.length} total events from local storage');
      return events;
    } catch (e) {
      print('CentralizedDataService: Error getting all local events: $e');
      return [];
    }
  }

  /// Updates local cache with fresh data from Google Sheets
  Future<void> _updateLocalCache(List<GameEvent> freshEvents) async {
    try {
      final gameEventsBox = Hive.box<GameEvent>('gameEvents');
      
      // Get existing unsynced events to preserve them
      final unsyncedEvents = gameEventsBox.values.where((event) => !event.isSynced).toList();
      
      // Create a set of fresh event IDs for quick lookup
      final freshEventIds = freshEvents.map((e) => e.id).toSet();
      
      // Remove synced events that are no longer in Google Sheets
      final syncedEventsToDelete = gameEventsBox.values
          .where((event) => event.isSynced && !freshEventIds.contains(event.id))
          .toList();
      
      for (final event in syncedEventsToDelete) {
        await event.delete();
      }
      
      // Add/update fresh events from Google Sheets
      for (final event in freshEvents) {
        await gameEventsBox.put(event.id, event);
      }
      
      // Restore unsynced events
      for (final event in unsyncedEvents) {
        if (!freshEventIds.contains(event.id)) {
          await gameEventsBox.put(event.id, event);
        }
      }
      
      print('CentralizedDataService: Updated local cache with ${freshEvents.length} fresh events');
    } catch (e) {
      print('CentralizedDataService: Error updating local cache: $e');
    }
  }

  /// Checks if the service is currently using cached data
  bool isUsingCachedData() {
    return _cachedEvents != null && 
           _lastEventsFetch != null && 
           DateTime.now().difference(_lastEventsFetch!) < _cacheValidDuration;
  }

  /// Gets the age of cached data
  Duration? getCacheAge() {
    if (_lastEventsFetch == null) return null;
    return DateTime.now().difference(_lastEventsFetch!);
  }
}
