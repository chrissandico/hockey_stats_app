import 'package:shared_preferences/shared_preferences.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'dart:convert';

/// Service to manage line configurations globally across the app
class LineConfigurationService {
  static LineConfigurationService? _instance;
  static LineConfigurationService get instance {
    _instance ??= LineConfigurationService._internal();
    return _instance!;
  }
  
  LineConfigurationService._internal();

  // Current line configurations - now dynamic
  List<List<Player?>> _forwardLines = [];
  List<List<Player?>> _defenseLines = [];

  // Getters for current configurations
  List<List<Player?>> get forwardLines => _forwardLines;
  List<List<Player?>> get defenseLines => _defenseLines;

  /// Calculate required number of forward lines based on player count
  int _calculateForwardLineCount(int forwardCount) {
    if (forwardCount <= 9) return 3; // Standard 3 lines for 9 or fewer forwards
    return 4; // 4 lines for 10+ forwards
  }

  /// Calculate required number of defense lines based on player count
  int _calculateDefenseLineCount(int defenseCount) {
    if (defenseCount <= 6) return 3; // Standard 3 lines for 6 or fewer defensemen
    return 4; // 4 lines for 7+ defensemen
  }

  /// Initialize line structure based on required counts
  void _initializeLineStructure(int forwardLineCount, int defenseLineCount) {
    // Initialize forward lines (3 players per line)
    _forwardLines = List.generate(forwardLineCount, (index) => [null, null, null]);
    
    // Initialize defense lines (2 players per line)
    _defenseLines = List.generate(defenseLineCount, (index) => [null, null]);
  }

  /// Initialize line configurations with players
  void initializeLines(List<Player> players) {
    // Get forwards and defensemen
    final forwards = players.where(_isForward).toList();
    final defensemen = players.where(_isDefenseman).toList();
    
    // Sort by jersey number
    forwards.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    defensemen.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Calculate required line counts based on player counts
    final forwardLineCount = _calculateForwardLineCount(forwards.length);
    final defenseLineCount = _calculateDefenseLineCount(defensemen.length);
    
    // Initialize line structure
    _initializeLineStructure(forwardLineCount, defenseLineCount);
    
    // Distribute forwards across lines (3 players per line)
    for (int lineIndex = 0; lineIndex < forwardLineCount; lineIndex++) {
      for (int posIndex = 0; posIndex < 3; posIndex++) {
        final playerIndex = lineIndex * 3 + posIndex;
        if (playerIndex < forwards.length) {
          _forwardLines[lineIndex][posIndex] = forwards[playerIndex];
        } else {
          _forwardLines[lineIndex][posIndex] = null;
        }
      }
    }
    
    // Distribute defensemen across lines (2 players per line)
    for (int lineIndex = 0; lineIndex < defenseLineCount; lineIndex++) {
      for (int posIndex = 0; posIndex < 2; posIndex++) {
        final playerIndex = lineIndex * 2 + posIndex;
        if (playerIndex < defensemen.length) {
          _defenseLines[lineIndex][posIndex] = defensemen[playerIndex];
        } else {
          _defenseLines[lineIndex][posIndex] = null;
        }
      }
    }
  }

  /// Load line configuration from persistent storage
  Future<void> loadLineConfiguration(String gameId, List<Player> players) async {
    try {
      // First initialize lines with current players to set up structure
      initializeLines(players);
      
      final prefs = await SharedPreferences.getInstance();
      final forwardConfig = prefs.getString('forward_lines_$gameId');
      final defenseConfig = prefs.getString('defense_lines_$gameId');
      
      if (forwardConfig != null) {
        final List<dynamic> config = json.decode(forwardConfig);
        for (int i = 0; i < config.length && i < _forwardLines.length; i++) {
          for (int j = 0; j < config[i].length && j < 3; j++) {
            final playerId = config[i][j];
            if (playerId != null) {
              final player = players.firstWhere(
                (p) => p.id == playerId,
                orElse: () => Player(id: '', jerseyNumber: 0),
              );
              if (player.id.isNotEmpty) {
                _forwardLines[i][j] = player;
              }
            } else {
              _forwardLines[i][j] = null;
            }
          }
        }
      }
      
      if (defenseConfig != null) {
        final List<dynamic> config = json.decode(defenseConfig);
        for (int i = 0; i < config.length && i < _defenseLines.length; i++) {
          for (int j = 0; j < config[i].length && j < 2; j++) {
            final playerId = config[i][j];
            if (playerId != null) {
              final player = players.firstWhere(
                (p) => p.id == playerId,
                orElse: () => Player(id: '', jerseyNumber: 0),
              );
              if (player.id.isNotEmpty) {
                _defenseLines[i][j] = player;
              }
            } else {
              _defenseLines[i][j] = null;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading line configuration: $e');
      // Fall back to default initialization if loading fails
      initializeLines(players);
    }
  }

  /// Save line configuration to persistent storage
  Future<void> saveLineConfiguration(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save forward lines
      final forwardConfig = _forwardLines.map((line) => 
        line.map((player) => player?.id).toList()
      ).toList();
      await prefs.setString('forward_lines_$gameId', json.encode(forwardConfig));
      
      // Save defense lines
      final defenseConfig = _defenseLines.map((line) => 
        line.map((player) => player?.id).toList()
      ).toList();
      await prefs.setString('defense_lines_$gameId', json.encode(defenseConfig));
    } catch (e) {
      print('Error saving line configuration: $e');
    }
  }

  /// Update a specific position in the line configuration
  void updatePosition(String positionType, int lineIndex, int positionIndex, Player? player) {
    if (positionType == 'forward' && lineIndex < _forwardLines.length && positionIndex < 3) {
      _forwardLines[lineIndex][positionIndex] = player;
    } else if (positionType == 'defense' && lineIndex < _defenseLines.length && positionIndex < 2) {
      _defenseLines[lineIndex][positionIndex] = player;
    }
  }

  /// Remove a player from all line positions
  void removePlayerFromLines(Player player) {
    // Remove from forward lines
    for (int i = 0; i < _forwardLines.length; i++) {
      for (int j = 0; j < _forwardLines[i].length; j++) {
        if (_forwardLines[i][j] == player) {
          _forwardLines[i][j] = null;
        }
      }
    }
    
    // Remove from defense lines
    for (int i = 0; i < _defenseLines.length; i++) {
      for (int j = 0; j < _defenseLines[i].length; j++) {
        if (_defenseLines[i][j] == player) {
          _defenseLines[i][j] = null;
        }
      }
    }
  }

  /// Find an empty spot for a player in the appropriate lines
  void findEmptySpotForPlayer(Player player, String positionType) {
    List<List<Player?>> lines = positionType == 'forward' ? _forwardLines : _defenseLines;
    
    for (int i = 0; i < lines.length; i++) {
      for (int j = 0; j < lines[i].length; j++) {
        if (lines[i][j] == null) {
          lines[i][j] = player;
          return;
        }
      }
    }
  }

  /// Get all players currently in lines
  List<Player> getAllPlayersInLines() {
    final List<Player> players = [];
    
    // Add forward players
    for (final line in _forwardLines) {
      for (final player in line) {
        if (player != null) {
          players.add(player);
        }
      }
    }
    
    // Add defense players
    for (final line in _defenseLines) {
      for (final player in line) {
        if (player != null) {
          players.add(player);
        }
      }
    }
    
    return players;
  }

  /// Helper methods for position checking
  bool _isForward(Player player) {
    return player.position == 'C' || 
           player.position == 'LW' || 
           player.position == 'RW' ||
           player.position == 'F';
  }
  
  bool _isDefenseman(Player player) {
    return player.position == 'D' || 
           player.position == 'LD' || 
           player.position == 'RD';
  }

  /// Reset line configuration to default state using Google Sheets as source of truth
  Future<void> resetLineConfigurationFromSheets(String gameId, List<Player> currentPlayers) async {
    try {
      print('Resetting line configuration for game $gameId using Google Sheets data');
      
      // Step 1: Clear corrupted saved configuration
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('forward_lines_$gameId');
      await prefs.remove('defense_lines_$gameId');
      print('Cleared saved configuration from SharedPreferences');
      
      // Step 2: Reinitialize with Google Sheets data (via currentPlayers)
      initializeLines(currentPlayers);
      print('Reinitialized lines with ${currentPlayers.length} players from Google Sheets');
      
      // Step 3: Save the clean default state
      await saveLineConfiguration(gameId);
      print('Saved clean default configuration');
      
    } catch (e) {
      print('Error resetting line configuration: $e');
      throw e; // Re-throw to allow UI error handling
    }
  }
}
