import 'dart:collection';
import 'package:hockey_stats_app/models/data_models.dart';

/// In-memory cache service for frequently accessed data
/// This reduces database I/O operations and improves performance
class MemoryCacheService {
  static final MemoryCacheService _instance = MemoryCacheService._internal();
  factory MemoryCacheService() => _instance;
  MemoryCacheService._internal();

  // Cache storage with LRU eviction
  final LinkedHashMap<String, GameEvent> _eventCache = LinkedHashMap<String, GameEvent>();
  final LinkedHashMap<String, Player> _playerCache = LinkedHashMap<String, Player>();
  final LinkedHashMap<String, Game> _gameCache = LinkedHashMap<String, Game>();
  final LinkedHashMap<String, GameRoster> _rosterCache = LinkedHashMap<String, GameRoster>();
  
  // Cache configuration
  static const int _maxEventCacheSize = 200;
  static const int _maxPlayerCacheSize = 100;
  static const int _maxGameCacheSize = 50;
  static const int _maxRosterCacheSize = 100;
  
  // Statistics for monitoring cache performance
  int _eventCacheHits = 0;
  int _eventCacheMisses = 0;
  int _playerCacheHits = 0;
  int _playerCacheMisses = 0;
  
  /// Cache a game event
  void cacheEvent(GameEvent event) {
    _eventCache[event.id] = event;
    _evictIfNeeded(_eventCache, _maxEventCacheSize);
  }
  
  /// Get a cached game event
  GameEvent? getEvent(String id) {
    final event = _eventCache[id];
    if (event != null) {
      _eventCacheHits++;
      // Move to end (most recently used)
      _eventCache.remove(id);
      _eventCache[id] = event;
      return event;
    } else {
      _eventCacheMisses++;
      return null;
    }
  }
  
  /// Cache a player
  void cachePlayer(Player player) {
    _playerCache[player.id] = player;
    _evictIfNeeded(_playerCache, _maxPlayerCacheSize);
  }
  
  /// Get a cached player
  Player? getPlayer(String id) {
    final player = _playerCache[id];
    if (player != null) {
      _playerCacheHits++;
      // Move to end (most recently used)
      _playerCache.remove(id);
      _playerCache[id] = player;
      return player;
    } else {
      _playerCacheMisses++;
      return null;
    }
  }
  
  /// Cache a game
  void cacheGame(Game game) {
    _gameCache[game.id] = game;
    _evictIfNeeded(_gameCache, _maxGameCacheSize);
  }
  
  /// Get a cached game
  Game? getGame(String id) {
    final game = _gameCache[id];
    if (game != null) {
      // Move to end (most recently used)
      _gameCache.remove(id);
      _gameCache[id] = game;
      return game;
    }
    return null;
  }
  
  /// Cache a roster entry
  void cacheRoster(GameRoster roster) {
    _rosterCache[roster.id] = roster;
    _evictIfNeeded(_rosterCache, _maxRosterCacheSize);
  }
  
  /// Get a cached roster entry
  GameRoster? getRoster(String id) {
    final roster = _rosterCache[id];
    if (roster != null) {
      // Move to end (most recently used)
      _rosterCache.remove(id);
      _rosterCache[id] = roster;
      return roster;
    }
    return null;
  }
  
  /// Get all cached events for a specific game
  List<GameEvent> getEventsForGame(String gameId) {
    return _eventCache.values
        .where((event) => event.gameId == gameId)
        .toList();
  }
  
  /// Get all cached players for a specific team
  List<Player> getPlayersForTeam(String teamId) {
    return _playerCache.values
        .where((player) => player.teamId == teamId)
        .toList();
  }
  
  /// Remove an event from cache
  void removeEvent(String id) {
    _eventCache.remove(id);
  }
  
  /// Remove a player from cache
  void removePlayer(String id) {
    _playerCache.remove(id);
  }
  
  /// Remove a game from cache
  void removeGame(String id) {
    _gameCache.remove(id);
  }
  
  /// Remove a roster entry from cache
  void removeRoster(String id) {
    _rosterCache.remove(id);
  }
  
  /// Clear all caches
  void clearAll() {
    _eventCache.clear();
    _playerCache.clear();
    _gameCache.clear();
    _rosterCache.clear();
    _resetStatistics();
  }
  
  /// Clear events cache
  void clearEvents() {
    _eventCache.clear();
  }
  
  /// Clear players cache
  void clearPlayers() {
    _playerCache.clear();
  }
  
  /// Clear games cache
  void clearGames() {
    _gameCache.clear();
  }
  
  /// Clear roster cache
  void clearRoster() {
    _rosterCache.clear();
  }
  
  /// Evict oldest entries if cache exceeds maximum size
  void _evictIfNeeded<T>(LinkedHashMap<String, T> cache, int maxSize) {
    while (cache.length > maxSize) {
      final firstKey = cache.keys.first;
      cache.remove(firstKey);
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getStatistics() {
    final eventHitRate = _eventCacheHits + _eventCacheMisses > 0 
        ? (_eventCacheHits / (_eventCacheHits + _eventCacheMisses) * 100).toStringAsFixed(1)
        : '0.0';
    
    final playerHitRate = _playerCacheHits + _playerCacheMisses > 0 
        ? (_playerCacheHits / (_playerCacheHits + _playerCacheMisses) * 100).toStringAsFixed(1)
        : '0.0';
    
    return {
      'eventCache': {
        'size': _eventCache.length,
        'maxSize': _maxEventCacheSize,
        'hits': _eventCacheHits,
        'misses': _eventCacheMisses,
        'hitRate': '$eventHitRate%',
      },
      'playerCache': {
        'size': _playerCache.length,
        'maxSize': _maxPlayerCacheSize,
        'hits': _playerCacheHits,
        'misses': _playerCacheMisses,
        'hitRate': '$playerHitRate%',
      },
      'gameCache': {
        'size': _gameCache.length,
        'maxSize': _maxGameCacheSize,
      },
      'rosterCache': {
        'size': _rosterCache.length,
        'maxSize': _maxRosterCacheSize,
      },
    };
  }
  
  /// Reset cache statistics
  void _resetStatistics() {
    _eventCacheHits = 0;
    _eventCacheMisses = 0;
    _playerCacheHits = 0;
    _playerCacheMisses = 0;
  }
  
  /// Preload frequently accessed data into cache
  Future<void> preloadCache() async {
    print('MemoryCacheService: Preloading cache with frequently accessed data...');
    
    try {
      // This would typically load recent events, active players, etc.
      // Implementation depends on your specific use patterns
      print('MemoryCacheService: Cache preloading completed');
    } catch (e) {
      print('MemoryCacheService: Error during cache preloading: $e');
    }
  }
  
  /// Warm up cache with game-specific data
  void warmUpForGame(String gameId, List<GameEvent> events, List<Player> players) {
    print('MemoryCacheService: Warming up cache for game $gameId');
    
    // Cache all events for this game
    for (final event in events) {
      cacheEvent(event);
    }
    
    // Cache all players
    for (final player in players) {
      cachePlayer(player);
    }
    
    print('MemoryCacheService: Cached ${events.length} events and ${players.length} players for game $gameId');
  }
}
