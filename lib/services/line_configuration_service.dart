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

  // Working line configurations (modified during drag/drop)
  List<List<Player?>> _forwardLines = [];
  List<List<Player?>> _defenseLines = [];

  // Saved line configurations (last explicitly saved state)
  List<List<Player?>> _savedForwardLines = [];
  List<List<Player?>> _savedDefenseLines = [];

  // Active Line Selection for On-Ice Tracking
  int _activeForwardLineIndex = 0;
  int _activeDefenseLineIndex = 0;

  int get activeForwardLineIndex => _activeForwardLineIndex;
  int get activeDefenseLineIndex => _activeDefenseLineIndex;

  // Getters for current working configurations
  List<List<Player?>> get forwardLines => _forwardLines;
  List<List<Player?>> get defenseLines => _defenseLines;
  
  // Getters for saved configurations
  List<List<Player?>> get savedForwardLines => _savedForwardLines;
  List<List<Player?>> get savedDefenseLines => _savedDefenseLines;

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

  String? _loadedGameId;

  /// Sync player references in current line configurations with updated Player list
  void syncPlayerReferences(List<Player> players) {
    if (players.isEmpty) return;

    final playerMap = {for (var p in players) p.id: p};

    for (int i = 0; i < _forwardLines.length; i++) {
      for (int j = 0; j < _forwardLines[i].length; j++) {
        final current = _forwardLines[i][j];
        if (current != null && playerMap.containsKey(current.id)) {
          _forwardLines[i][j] = playerMap[current.id];
        }
      }
    }

    for (int i = 0; i < _defenseLines.length; i++) {
      for (int j = 0; j < _defenseLines[i].length; j++) {
        final current = _defenseLines[i][j];
        if (current != null && playerMap.containsKey(current.id)) {
          _defenseLines[i][j] = playerMap[current.id];
        }
      }
    }

    for (int i = 0; i < _savedForwardLines.length; i++) {
      for (int j = 0; j < _savedForwardLines[i].length; j++) {
        final current = _savedForwardLines[i][j];
        if (current != null && playerMap.containsKey(current.id)) {
          _savedForwardLines[i][j] = playerMap[current.id];
        }
      }
    }

    for (int i = 0; i < _savedDefenseLines.length; i++) {
      for (int j = 0; j < _savedDefenseLines[i].length; j++) {
        final current = _savedDefenseLines[i][j];
        if (current != null && playerMap.containsKey(current.id)) {
          _savedDefenseLines[i][j] = playerMap[current.id];
        }
      }
    }
  }

  /// Auto-save working line configuration to persistent storage
  Future<void> saveWorkingLines(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final workingFConfig = _forwardLines.map((line) =>
        line.map((player) => player?.id).toList()
      ).toList();
      await prefs.setString('working_forward_lines_$gameId', json.encode(workingFConfig));

      final workingDConfig = _defenseLines.map((line) =>
        line.map((player) => player?.id).toList()
      ).toList();
      await prefs.setString('working_defense_lines_$gameId', json.encode(workingDConfig));
    } catch (e) {
      print('Error auto-saving working line configuration: $e');
    }
  }

  /// Whether a decoded saved line config can belong to the roster
  /// identified by [rosterIds]: true when the config references no
  /// players at all (an intentionally emptied setup) or at least one
  /// player who is on the current roster. A config whose every
  /// referenced player is missing belongs to a different team or
  /// season and must never be applied: _applyConfigList resolves
  /// missing IDs to empty slots, so applying a foreign config wipes
  /// the auto-dealt lines and leaves every slot blank.
  static bool configBelongsToRoster(List<dynamic> config, Set<String> rosterIds) {
    var referencedAny = false;
    for (final line in config) {
      if (line is List) {
        for (final id in line) {
          if (id != null) {
            referencedAny = true;
            if (rosterIds.contains(id.toString())) return true;
          }
        }
      }
    }
    return !referencedAny;
  }

  /// Load line configuration from persistent storage
  Future<void> loadLineConfiguration(String gameId, List<Player> players, {bool forceReload = false}) async {
    try {
      if (players.isEmpty) return;

      // If lines are already loaded for this game and not forcing reload, just sync player object references
      if (!forceReload && _loadedGameId == gameId && _forwardLines.isNotEmpty && _defenseLines.isNotEmpty) {
        syncPlayerReferences(players);
        return;
      }

      _loadedGameId = gameId;

      // Initialize structure with current players
      initializeLines(players);
      
      final prefs = await SharedPreferences.getInstance();

      final teamId = players.where((p) => p.teamId != null && p.teamId!.isNotEmpty).firstOrNull?.teamId;

      // 1. Check if there's a game-specific working or saved config
      String? fConfigStr = prefs.getString('working_forward_lines_$gameId') ??
                           prefs.getString('saved_forward_lines_$gameId');
      String? dConfigStr = prefs.getString('working_defense_lines_$gameId') ??
                           prefs.getString('saved_defense_lines_$gameId');

      // 2. If no game-specific config exists yet for a new game, fallback to team default config or 'current_game'
      if ((fConfigStr == null || dConfigStr == null) && teamId != null && teamId.isNotEmpty) {
        fConfigStr ??= prefs.getString('saved_forward_lines_team_$teamId') ??
                       prefs.getString('saved_forward_lines_current_game');
        dConfigStr ??= prefs.getString('saved_defense_lines_team_$teamId') ??
                       prefs.getString('saved_defense_lines_current_game');
      }

      if (fConfigStr != null && dConfigStr != null) {
        // Never apply a saved setup that belongs to another team or
        // season. This matters because the fallback chain can surface
        // the device-wide 'current_game' config, which on a phone used
        // for more than one team holds a DIFFERENT team's player IDs;
        // applying it nulled every slot (Oct 2026, Stars U15 BB setup).
        final rosterIds = players.map((p) => p.id).toSet();
        final fConfig = json.decode(fConfigStr) as List<dynamic>;
        final dConfig = json.decode(dConfigStr) as List<dynamic>;
        if (configBelongsToRoster(fConfig, rosterIds)) {
          _applyConfigList(fConfig, _forwardLines, players, 3);
        } else {
          print('Saved forward lines do not match this roster - keeping the auto-dealt lines');
        }
        if (configBelongsToRoster(dConfig, rosterIds)) {
          _applyConfigList(dConfig, _defenseLines, players, 2);
        } else {
          print('Saved defense lines do not match this roster - keeping the auto-dealt lines');
        }
        _copyWorkingToSaved();
      } else {
        // Default saved is initial default
        _copyWorkingToSaved();
      }
    } catch (e) {
      print('Error loading line configuration: $e');
      initializeLines(players);
      _copyWorkingToSaved();
    }
  }

  void _applyConfigList(List<dynamic> config, List<List<Player?>> targetLines, List<Player> players, int maxPos) {
    for (int i = 0; i < config.length && i < targetLines.length; i++) {
      for (int j = 0; j < maxPos; j++) {
        if (j < config[i].length) {
          final playerId = config[i][j];
          if (playerId != null) {
            final player = players.firstWhere(
              (p) => p.id == playerId,
              orElse: () => Player(id: '', jerseyNumber: 0),
            );
            if (player.id.isNotEmpty) {
              targetLines[i][j] = player;
            } else {
              targetLines[i][j] = null;
            }
          } else {
            targetLines[i][j] = null;
          }
        } else {
          // Explicitly clear extra slots if loaded row had fewer slots than maxPos
          targetLines[i][j] = null;
        }
      }
    }
  }

  /// Save current working line configuration to persistent storage
  Future<void> saveLineConfiguration(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final forwardConfig = _forwardLines.map((line) =>
        line.map((player) => player?.id).toList()
      ).toList();
      final defenseConfig = _defenseLines.map((line) =>
        line.map((player) => player?.id).toList()
      ).toList();

      final fJson = json.encode(forwardConfig);
      final dJson = json.encode(defenseConfig);

      // Save game-specific config
      await prefs.setString('saved_forward_lines_$gameId', fJson);
      await prefs.setString('working_forward_lines_$gameId', fJson);
      await prefs.setString('saved_defense_lines_$gameId', dJson);
      await prefs.setString('working_defense_lines_$gameId', dJson);

      // Also save as team default config so future games start with this lineup!
      final teamId = _forwardLines.expand((line) => line).whereType<Player>().firstOrNull?.teamId ??
                     _defenseLines.expand((line) => line).whereType<Player>().firstOrNull?.teamId;
      if (teamId != null && teamId.isNotEmpty) {
        await prefs.setString('saved_forward_lines_team_$teamId', fJson);
        await prefs.setString('saved_defense_lines_team_$teamId', dJson);
      }
      await prefs.setString('saved_forward_lines_current_game', fJson);
      await prefs.setString('saved_defense_lines_current_game', dJson);

      // Update saved state in memory
      _copyWorkingToSaved();
      
      print('Line configuration saved for game $gameId (and updated team default)');
    } catch (e) {
      print('Error saving line configuration: $e');
      rethrow;
    }
  }
  
  /// Copy working configuration to saved configuration (in memory)
  void _copyWorkingToSaved() {
    _savedForwardLines = _forwardLines.map((line) => List<Player?>.from(line)).toList();
    _savedDefenseLines = _defenseLines.map((line) => List<Player?>.from(line)).toList();
  }
  
  /// Copy saved configuration to working configuration (restore)
  void _copySavedToWorking() {
    _forwardLines = _savedForwardLines.map((line) => List<Player?>.from(line)).toList();
    _defenseLines = _savedDefenseLines.map((line) => List<Player?>.from(line)).toList();
  }
  
  /// Reset working configuration to last saved state
  void resetToSavedConfiguration(String gameId) {
    _copySavedToWorking();
    saveWorkingLines(gameId);
    print('Reset to last saved configuration');
  }
  
  /// Check if current working configuration differs from saved configuration
  bool hasUnsavedChanges() {
    // Compare forward lines
    if (_forwardLines.length != _savedForwardLines.length) return true;
    for (int i = 0; i < _forwardLines.length; i++) {
      if (_forwardLines[i].length != _savedForwardLines[i].length) return true;
      for (int j = 0; j < _forwardLines[i].length; j++) {
        if (_forwardLines[i][j]?.id != _savedForwardLines[i][j]?.id) return true;
      }
    }
    
    // Compare defense lines
    if (_defenseLines.length != _savedDefenseLines.length) return true;
    for (int i = 0; i < _defenseLines.length; i++) {
      if (_defenseLines[i].length != _savedDefenseLines[i].length) return true;
      for (int j = 0; j < _defenseLines[i].length; j++) {
        if (_defenseLines[i][j]?.id != _savedDefenseLines[i][j]?.id) return true;
      }
    }
    
    return false;
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

  /// Set active line selection for live on-ice tracking
  void setActiveLineIndices(int forwardIndex, int defenseIndex) {
    if (forwardIndex >= 0 && forwardIndex < _forwardLines.length) {
      _activeForwardLineIndex = forwardIndex;
    }
    if (defenseIndex >= 0 && defenseIndex < _defenseLines.length) {
      _activeDefenseLineIndex = defenseIndex;
    }
  }

  /// Get list of active on-ice players (combination of active forward line + defense pair)
  List<Player> getActiveOnIcePlayers() {
    final List<Player> active = [];

    if (_activeForwardLineIndex < _forwardLines.length) {
      for (final player in _forwardLines[_activeForwardLineIndex]) {
        if (player != null) active.add(player);
      }
    }

    if (_activeDefenseLineIndex < _defenseLines.length) {
      for (final player in _defenseLines[_activeDefenseLineIndex]) {
        if (player != null) active.add(player);
      }
    }

    return active;
  }

  /// Get active on-ice player IDs for auto-populating GameEvents
  List<String> getActiveOnIcePlayerIds() {
    return getActiveOnIcePlayers().map((p) => p.id).toList();
  }

  /// Helper methods for position checking
  bool _isForward(Player player) {
    if (player.position == 'G') return false;
    if (_isDefenseman(player)) return false;
    return true; // Fallback: Treat any non-goalie, non-defense skater as forward so they are never omitted
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
      
      // Step 1: Clear saved configuration
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_forward_lines_$gameId');
      await prefs.remove('saved_defense_lines_$gameId');
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
