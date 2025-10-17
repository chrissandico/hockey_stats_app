import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/line_configuration_service.dart';

// Data class to represent a line position
class LinePosition {
  final int lineIndex;
  final int positionIndex;
  final String positionType; // 'forward' or 'defense'
  
  LinePosition({
    required this.lineIndex,
    required this.positionIndex,
    required this.positionType,
  });
}

// Draggable player button widget
class _DraggablePlayerButton extends StatelessWidget {
  final Player player;
  final bool isOnIce;
  final bool isGoalScorer;
  final bool isAssist1;
  final bool isAssist2;
  final bool isSelectedGoalie;
  final bool isAbsent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final bool isDragging;
  final double width;
  final double height;
  final double jerseyFontSize;
  final double positionBadgeFontSize;
  final double iconSize;
  final double smallIconSize;

  const _DraggablePlayerButton({
    required this.player,
    required this.isOnIce,
    required this.isGoalScorer,
    required this.isAssist1,
    required this.isAssist2,
    required this.isSelectedGoalie,
    required this.isAbsent,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
    this.isDragging = false,
    this.width = 80.0,
    this.height = 50.0,
    this.jerseyFontSize = 16.0,
    this.positionBadgeFontSize = 8.0,
    this.iconSize = 12.0,
    this.smallIconSize = 10.0,
  });

  // Cache for color calculations to avoid redundant processing
  static final Map<String, Color> _colorCache = {};
  
  Color _getCachedColor(String key, Color Function() calculator) {
    return _colorCache.putIfAbsent(key, calculator);
  }

  Color get _backgroundColor {
    final key = 'bg_${isAbsent}_${isGoalScorer}_${isAssist1}_${isAssist2}_${isSelectedGoalie}_${isOnIce}_${isDragging}';
    return _getCachedColor(key, () {
      if (isDragging) return Colors.blue.withOpacity(0.1);
      if (isAbsent) return Colors.grey.withOpacity(0.3);
      if (isGoalScorer) return Colors.green.withOpacity(0.2);
      if (isAssist1 || isAssist2) return Colors.orange.withOpacity(0.2);
      if (isSelectedGoalie) return Colors.purple.withOpacity(0.2);
      if (isOnIce) return Colors.blue.withOpacity(0.2);
      return Colors.grey.withOpacity(0.1);
    });
  }

  Color get _borderColor {
    final key = 'border_${isAbsent}_${isGoalScorer}_${isAssist1}_${isAssist2}_${isSelectedGoalie}_${isOnIce}_${isDragging}';
    return _getCachedColor(key, () {
      if (isDragging) return Colors.blue.withOpacity(0.3);
      if (isAbsent) return Colors.grey;
      if (isGoalScorer) return Colors.green;
      if (isAssist1 || isAssist2) return Colors.orange;
      if (isSelectedGoalie) return Colors.purple;
      if (isOnIce) return Colors.blue;
      return Colors.grey.withOpacity(0.5);
    });
  }

  Color get _textColor {
    final key = 'text_${isAbsent}_${isGoalScorer}_${isAssist1}_${isAssist2}_${isSelectedGoalie}_${isOnIce}_${isDragging}';
    return _getCachedColor(key, () {
      if (isDragging) return Colors.blue.withOpacity(0.7);
      if (isAbsent) return Colors.grey;
      if (isGoalScorer) return Colors.green;
      if (isAssist1 || isAssist2) return Colors.orange;
      if (isSelectedGoalie) return Colors.purple;
      if (isOnIce) return Colors.blue;
      return Colors.black87;
    });
  }

  Widget _buildPlayerJersey() {
    final isForward = player.position == 'C' || 
                     player.position == 'LW' || 
                     player.position == 'RW' ||
                     player.position == 'F';
    final isDefenseman = player.position == 'D' || 
                        player.position == 'LD' || 
                        player.position == 'RD';
    final isGoalie = player.position == 'G';
    
    String positionLabel;
    Color positionColor;
    if (isGoalie) {
      positionLabel = 'G';
      positionColor = Colors.purple.withOpacity(0.8);
    } else if (isForward) {
      positionLabel = 'F';
      positionColor = Colors.orange.withOpacity(0.8);
    } else {
      positionLabel = 'D';
      positionColor = Colors.green.withOpacity(0.8);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _borderColor,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '#${player.jerseyNumber}',
              style: TextStyle(
                fontSize: jerseyFontSize,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          // Position indicator badge
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: positionColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                positionLabel,
                style: TextStyle(
                  fontSize: positionBadgeFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Role indicators
          if (isGoalScorer)
            Positioned(
              top: 2,
              right: 2,
              child: Icon(
                Icons.sports_score,
                size: iconSize,
                color: Colors.green,
              ),
            ),
          if (isAssist1)
            Positioned(
              bottom: 2,
              right: 2,
              child: Icon(
                Icons.looks_one,
                size: iconSize,
                color: Colors.orange,
              ),
            ),
          if (isAssist2)
            Positioned(
              bottom: 2,
              right: iconSize + 2,
              child: Icon(
                Icons.looks_two,
                size: smallIconSize,
                color: Colors.orange,
              ),
            ),
          if (isSelectedGoalie)
            Positioned(
              bottom: 2,
              right: 2,
              child: Icon(
                Icons.check_circle,
                size: iconSize,
                color: Colors.purple,
              ),
            ),
          if (isAbsent)
            Positioned(
              bottom: 2,
              left: 2,
              child: Icon(
                Icons.person_off,
                size: smallIconSize,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Draggable<Player>(
        data: player,
        feedback: Material(
          elevation: 6.0,
          borderRadius: BorderRadius.circular(8),
          child: Transform.scale(
            scale: 1.1,
            child: _buildPlayerJersey(),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildPlayerJersey(),
        ),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          onDoubleTap: onDoubleTap,
          child: _buildPlayerJersey(),
        ),
      ),
    );
  }
}

// Player button wrapper for drop targets that gets state from parent
class _PlayerButtonInDropTarget extends StatelessWidget {
  final Player player;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;

  const _PlayerButtonInDropTarget({
    required this.player,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Find the parent PlayerSelectionWidget to get the current state
    final parentState = context.findAncestorStateOfType<_PlayerSelectionWidgetState>();
    if (parentState == null) {
      return Container(); // Fallback if parent not found
    }

    final isOnIce = parentState.widget.selectedPlayersOnIce.contains(player);
    final isGoalScorer = parentState.widget.selectedGoalScorer == player;
    final isAssist1 = parentState.widget.selectedAssist1 == player;
    final isAssist2 = parentState.widget.selectedAssist2 == player;
    final isSelectedGoalie = parentState.widget.selectedGoalie == player;
    final isAbsent = parentState._isPlayerAbsent(player);

    return _DraggablePlayerButton(
      player: player,
      isOnIce: isOnIce,
      isGoalScorer: isGoalScorer,
      isAssist1: isAssist1,
      isAssist2: isAssist2,
      isSelectedGoalie: isSelectedGoalie,
      isAbsent: isAbsent,
      width: parentState._playerBoxWidth,
      height: parentState._playerBoxHeight,
      jerseyFontSize: parentState._jerseyFontSize,
      positionBadgeFontSize: parentState._positionBadgeFontSize,
      iconSize: parentState._iconSize,
      smallIconSize: parentState._smallIconSize,
      onTap: () => onPlayerTap(player),
      onLongPress: () => onPlayerLongPress(player),
      onDoubleTap: () => onPlayerLongPress(player),
    );
  }
}

// Drop target for line positions
class _LinePositionDropTarget extends StatelessWidget {
  final Player? player;
  final LinePosition position;
  final Function(Player, LinePosition) onPlayerDropped;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;
  final bool isHighlighted;

  const _LinePositionDropTarget({
    this.player,
    required this.position,
    required this.onPlayerDropped,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
    this.isHighlighted = false,
  });

  bool _canAcceptPlayer(Player? draggedPlayer) {
    if (draggedPlayer == null) return false;
    
    final isForward = draggedPlayer.position == 'C' || 
                     draggedPlayer.position == 'LW' || 
                     draggedPlayer.position == 'RW' ||
                     draggedPlayer.position == 'F';
    final isDefenseman = draggedPlayer.position == 'D' || 
                        draggedPlayer.position == 'LD' || 
                        draggedPlayer.position == 'RD';
    final isGoalie = draggedPlayer.position == 'G';
    
    // Goalies cannot be dropped in skater positions
    if (isGoalie) return false;
    
    // Allow forwards and defensemen to be placed in any skater position
    // This enables position flexibility during games
    return (position.positionType == 'forward' || position.positionType == 'defense') &&
           (isForward || isDefenseman);
  }

  @override
  Widget build(BuildContext context) {
    // Get parent state for dynamic sizing
    final parentState = context.findAncestorStateOfType<_PlayerSelectionWidgetState>();
    final width = parentState?._playerBoxWidth ?? 80.0;
    final height = parentState?._playerBoxHeight ?? 50.0;
    
    return DragTarget<Player>(
      builder: (context, candidateData, rejectedData) {
        final showHighlight = candidateData.isNotEmpty && _canAcceptPlayer(candidateData.first);
        
        return Container(
          width: width,
          height: height,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: showHighlight 
                ? Colors.blue.withOpacity(0.2)
                : isHighlighted
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: showHighlight 
                  ? Colors.blue
                  : isHighlighted
                      ? Colors.blue.withOpacity(0.5)
                      : Colors.grey.withOpacity(0.3),
              width: showHighlight ? 2 : 1,
              style: player == null ? BorderStyle.solid : BorderStyle.none,
            ),
          ),
          child: player != null
              ? _PlayerButtonInDropTarget(
                  player: player!,
                  onPlayerTap: onPlayerTap,
                  onPlayerLongPress: onPlayerLongPress,
                )
              : Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.grey.withOpacity(0.5),
                    size: 20,
                  ),
                ),
        );
      },
      onWillAccept: _canAcceptPlayer,
      onAccept: (player) => onPlayerDropped(player, position),
    );
  }
}

// Line header with selection functionality
class _LineHeader extends StatelessWidget {
  final String lineLabel;
  final List<Player?> playersInLine;
  final Set<Player> selectedPlayers;
  final VoidCallback onLineToggle;

  const _LineHeader({
    required this.lineLabel,
    required this.playersInLine,
    required this.selectedPlayers,
    required this.onLineToggle,
  });

  @override
  Widget build(BuildContext context) {
    final nonNullPlayers = playersInLine.where((p) => p != null).cast<Player>().toList();
    final selectedInLine = nonNullPlayers.where((p) => selectedPlayers.contains(p)).length;
    final allSelected = selectedInLine == nonNullPlayers.length && nonNullPlayers.isNotEmpty;
    final partiallySelected = selectedInLine > 0 && selectedInLine < nonNullPlayers.length;

    return GestureDetector(
      onTap: onLineToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue),
            color: allSelected 
                ? Colors.blue 
                : partiallySelected 
                    ? Colors.blue.withOpacity(0.5) 
                    : Colors.transparent,
          ),
          child: allSelected || partiallySelected
              ? const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class PlayerSelectionWidget extends StatefulWidget {
  final List<Player> players;
  final List<Player> goalies;
  final Set<String> absentPlayerIds;
  final List<Player> selectedPlayersOnIce;
  final Player? selectedGoalScorer;
  final Player? selectedAssist1;
  final Player? selectedAssist2;
  final Player? selectedGoalie;
  final Function(List<Player>) onPlayersOnIceChanged;
  final Function(Player?) onGoalScorerChanged;
  final Function(Player?) onAssist1Changed;
  final Function(Player?)? onAssist2Changed;
  final Function(Player?) onGoalieChanged;

  const PlayerSelectionWidget({
    super.key,
    required this.players,
    required this.goalies,
    required this.absentPlayerIds,
    required this.selectedPlayersOnIce,
    required this.selectedGoalScorer,
    required this.selectedAssist1,
    this.selectedAssist2,
    required this.selectedGoalie,
    required this.onPlayersOnIceChanged,
    required this.onGoalScorerChanged,
    required this.onAssist1Changed,
    this.onAssist2Changed,
    required this.onGoalieChanged,
  });

  @override
  State<PlayerSelectionWidget> createState() => _PlayerSelectionWidgetState();
}

class _PlayerSelectionWidgetState extends State<PlayerSelectionWidget> {
  final LineConfigurationService _lineService = LineConfigurationService.instance;
  String? _currentGameId;

  // Compact mode detection - activate when team has >15 players
  bool get _isCompactMode {
    final totalPlayers = widget.players.length;
    return totalPlayers > 15;
  }

  // Dynamic sizing based on compact mode
  double get _playerBoxWidth => _isCompactMode ? 65.0 : 80.0;
  double get _playerBoxHeight => _isCompactMode ? 40.0 : 50.0;
  double get _jerseyFontSize => _isCompactMode ? 14.0 : 16.0;
  double get _positionBadgeFontSize => _isCompactMode ? 7.0 : 8.0;
  double get _lineVerticalPadding => _isCompactMode ? 1.0 : 2.0;
  double get _sectionSpacing => _isCompactMode ? 6.0 : 8.0;
  double get _cardPadding => _isCompactMode ? 6.0 : 8.0;
  double get _iconSize => _isCompactMode ? 10.0 : 12.0;
  double get _smallIconSize => _isCompactMode ? 8.0 : 10.0;

  @override
  void initState() {
    super.initState();
    _initializeLines();
  }

  @override
  void didUpdateWidget(PlayerSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.players != widget.players) {
      _initializeLines();
    }
  }

  void _initializeLines() async {
    // For now, use a default game ID. In a real implementation, this would come from the current game context
    _currentGameId = 'current_game';
    
    // Initialize lines with current players
    _lineService.initializeLines(widget.players);
    
    // Load saved configuration for this game
    await _lineService.loadLineConfiguration(_currentGameId!, widget.players);
    
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveLineConfiguration() async {
    if (_currentGameId != null) {
      await _lineService.saveLineConfiguration(_currentGameId!);
    }
  }

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

  bool _isGoalie(Player player) {
    return player.position == 'G';
  }
  
  bool _isPlayerAbsent(Player player) {
    return widget.absentPlayerIds.contains(player.id);
  }

  void _handlePlayerDropped(Player player, LinePosition position) {
    if (_isPlayerAbsent(player)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot move absent player'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      // Find the current position of the dragged player
      LinePosition? currentPosition = _findPlayerPosition(player);
      
      // Check if there's already a player in the target position
      List<List<Player?>> targetLines = position.positionType == 'forward' 
          ? _lineService.forwardLines 
          : _lineService.defenseLines;
      Player? existingPlayer = targetLines[position.lineIndex][position.positionIndex];
      
      // Remove the dragged player from their current position
      _lineService.removePlayerFromLines(player);
      
      // Place the dragged player in the target position
      _lineService.updatePosition(position.positionType, position.lineIndex, position.positionIndex, player);
      
      // If there was a player in the target position, swap them to the dragged player's original position
      if (existingPlayer != null && currentPosition != null) {
        // Place the displaced player in the dragged player's original position
        _lineService.updatePosition(currentPosition.positionType, currentPosition.lineIndex, currentPosition.positionIndex, existingPlayer);
      } else if (existingPlayer != null) {
        // If we couldn't find the original position, find any empty spot for the displaced player
        // Try to place in appropriate position type first (forward for forward, defense for defense)
        final isForward = existingPlayer.position == 'C' || 
                         existingPlayer.position == 'LW' || 
                         existingPlayer.position == 'RW' ||
                         existingPlayer.position == 'F';
        final preferredPositionType = isForward ? 'forward' : 'defense';
        
        _lineService.findEmptySpotForPlayer(existingPlayer, preferredPositionType);
        
        // If no spot found in preferred type, try the other type (since we now allow flexibility)
        if (!_isPlayerInLines(existingPlayer)) {
          final alternatePositionType = isForward ? 'defense' : 'forward';
          _lineService.findEmptySpotForPlayer(existingPlayer, alternatePositionType);
        }
      }
    });
    
    _saveLineConfiguration();
  }

  void _removePlayerFromLines(Player player) {
    _lineService.removePlayerFromLines(player);
  }

  void _findEmptySpotForPlayer(Player player, String positionType) {
    _lineService.findEmptySpotForPlayer(player, positionType);
  }

  /// Find the current position of a player in the lines
  LinePosition? _findPlayerPosition(Player player) {
    // Check forward lines
    for (int lineIndex = 0; lineIndex < _lineService.forwardLines.length; lineIndex++) {
      for (int posIndex = 0; posIndex < _lineService.forwardLines[lineIndex].length; posIndex++) {
        if (_lineService.forwardLines[lineIndex][posIndex] == player) {
          return LinePosition(
            lineIndex: lineIndex,
            positionIndex: posIndex,
            positionType: 'forward',
          );
        }
      }
    }
    
    // Check defense lines
    for (int lineIndex = 0; lineIndex < _lineService.defenseLines.length; lineIndex++) {
      for (int posIndex = 0; posIndex < _lineService.defenseLines[lineIndex].length; posIndex++) {
        if (_lineService.defenseLines[lineIndex][posIndex] == player) {
          return LinePosition(
            lineIndex: lineIndex,
            positionIndex: posIndex,
            positionType: 'defense',
          );
        }
      }
    }
    
    return null;
  }

  /// Check if a player is currently placed in any line position
  bool _isPlayerInLines(Player player) {
    return _findPlayerPosition(player) != null;
  }

  /// Reset line configuration to default using Google Sheets as source of truth
  Future<void> _resetLineConfiguration() async {
    if (_currentGameId != null) {
      try {
        // Reset configuration using Google Sheets as source of truth
        await _lineService.resetLineConfigurationFromSheets(_currentGameId!, widget.players);
        
        // Refresh UI
        if (mounted) {
          setState(() {});
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Line configuration reset to default'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting configuration: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handlePlayerTap(Player player) {
    if (_isPlayerAbsent(player)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot select absent player'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final isGoalie = _isGoalie(player);
    
    if (isGoalie) {
      // Toggle goalie selection
      if (widget.selectedGoalie == player) {
        widget.onGoalieChanged(null);
      } else {
        widget.onGoalieChanged(player);
      }
    } else {
      // Toggle skater on ice
      List<Player> newPlayersOnIce = List.from(widget.selectedPlayersOnIce);
      final currentGoalieCount = widget.selectedGoalie != null ? 1 : 0;
      
      if (newPlayersOnIce.contains(player)) {
        newPlayersOnIce.remove(player);
      } else {
        final totalPlayersAfterAdd = newPlayersOnIce.length + 1 + currentGoalieCount;
        if (totalPlayersAfterAdd <= 6) {
          newPlayersOnIce.add(player);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 6 total players on ice (including goalie)'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }
      widget.onPlayersOnIceChanged(newPlayersOnIce);
    }
  }

  void _handleLineToggle(List<Player?> playersInLine) {
    final nonNullPlayers = playersInLine.where((p) => p != null).cast<Player>().toList();
    final availablePlayers = nonNullPlayers.where((p) => !_isPlayerAbsent(p)).toList();
    
    if (availablePlayers.isEmpty) return;
    
    final selectedPlayersSet = widget.selectedPlayersOnIce.toSet();
    final selectedInLine = availablePlayers.where((p) => selectedPlayersSet.contains(p)).length;
    final allSelected = selectedInLine == availablePlayers.length;
    
    List<Player> newPlayersOnIce = List.from(widget.selectedPlayersOnIce);
    final currentGoalieCount = widget.selectedGoalie != null ? 1 : 0;
    
    if (allSelected) {
      // Deselect all players in the line
      for (final player in availablePlayers) {
        newPlayersOnIce.remove(player);
      }
    } else {
      // Select all players in the line (up to the limit)
      final currentSelectionCount = newPlayersOnIce.length;
      final availableSlots = 6 - currentSelectionCount - currentGoalieCount;
      
      final playersToAdd = availablePlayers.where(
        (p) => !newPlayersOnIce.contains(p)
      ).take(availableSlots).toList();
      
      if (playersToAdd.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum players on ice reached')),
        );
        return;
      }
      
      newPlayersOnIce.addAll(playersToAdd);
    }
    
    widget.onPlayersOnIceChanged(newPlayersOnIce);
  }

  void _showPlayerRoleDialog(Player player) {
    final isOnIce = widget.selectedPlayersOnIce.contains(player);
    final isGoalScorer = widget.selectedGoalScorer == player;
    final isAssist1 = widget.selectedAssist1 == player;
    final isAssist2 = widget.selectedAssist2 == player;
    final isSelectedGoalie = widget.selectedGoalie == player;
    final isAbsent = _isPlayerAbsent(player);
    final isGoalie = _isGoalie(player);
    
    // Only show dialog for selected players
    if (!isOnIce && !isSelectedGoalie) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text('Player #${player.jerseyNumber}'),
              if (isAbsent) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.person_off,
                  size: 16,
                  color: Colors.grey,
                ),
                const Text(
                  ' (Absent)',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGoalie) ...[
                const Text(
                  'Goalie is currently in net.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.sports_score, color: Colors.green),
                  title: const Text('Goal Scorer'),
                  trailing: Switch(
                    value: isGoalScorer,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      if (value) {
                        widget.onGoalScorerChanged(player);
                      } else if (widget.selectedGoalScorer == player) {
                        widget.onGoalScorerChanged(null);
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.looks_one, color: Colors.orange),
                  title: const Text('1st Assist'),
                  trailing: Switch(
                    value: isAssist1,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      if (value) {
                        if (widget.selectedAssist2 == player && widget.onAssist2Changed != null) {
                          widget.onAssist2Changed!(null);
                        }
                        widget.onAssist1Changed(player);
                      } else if (widget.selectedAssist1 == player) {
                        widget.onAssist1Changed(null);
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                if (widget.onAssist2Changed != null)
                  ListTile(
                    leading: const Icon(Icons.looks_two, color: Colors.orange),
                    title: const Text('2nd Assist'),
                    trailing: Switch(
                      value: isAssist2,
                      activeColor: Colors.orange,
                      onChanged: (value) {
                        if (value) {
                          if (widget.selectedAssist1 == player) {
                            widget.onAssist1Changed(null);
                          }
                          widget.onAssist2Changed!(player);
                        } else if (widget.selectedAssist2 == player) {
                          widget.onAssist2Changed!(null);
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildForwardLines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'FORWARDS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        ...List.generate(_lineService.forwardLines.length, (lineIndex) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: _lineVerticalPadding),
            child: Row(
              children: [
                // Line selector on the left - flexible width
                Flexible(
                  flex: 1,
                  child: _LineHeader(
                    lineLabel: 'LINE ${lineIndex + 1}',
                    playersInLine: _lineService.forwardLines[lineIndex],
                    selectedPlayers: widget.selectedPlayersOnIce.toSet(),
                    onLineToggle: () => _handleLineToggle(_lineService.forwardLines[lineIndex]),
                  ),
                ),
                const SizedBox(width: 4),
                // Player positions on the right
                Expanded(
                  flex: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(3, (posIndex) {
                      final player = _lineService.forwardLines[lineIndex][posIndex];
                      final position = LinePosition(
                        lineIndex: lineIndex,
                        positionIndex: posIndex,
                        positionType: 'forward',
                      );
                      
                      return _LinePositionDropTarget(
                        player: player,
                        position: position,
                        onPlayerDropped: _handlePlayerDropped,
                        onPlayerTap: _handlePlayerTap,
                        onPlayerLongPress: _showPlayerRoleDialog,
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDefenseLines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'DEFENSE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
        ...List.generate(_lineService.defenseLines.length, (lineIndex) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: _lineVerticalPadding),
            child: Row(
              children: [
                // Line selector on the left - flexible width
                Flexible(
                  flex: 1,
                  child: _LineHeader(
                    lineLabel: 'LINE ${lineIndex + 1}',
                    playersInLine: _lineService.defenseLines[lineIndex],
                    selectedPlayers: widget.selectedPlayersOnIce.toSet(),
                    onLineToggle: () => _handleLineToggle(_lineService.defenseLines[lineIndex]),
                  ),
                ),
                const SizedBox(width: 4),
                // Player positions on the right
                Expanded(
                  flex: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(2, (posIndex) {
                      final player = _lineService.defenseLines[lineIndex][posIndex];
                      final position = LinePosition(
                        lineIndex: lineIndex,
                        positionIndex: posIndex,
                        positionType: 'defense',
                      );
                      
                      return _LinePositionDropTarget(
                        player: player,
                        position: position,
                        onPlayerDropped: _handlePlayerDropped,
                        onPlayerTap: _handlePlayerTap,
                        onPlayerLongPress: _showPlayerRoleDialog,
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGoalieSection() {
    final goalies = [...widget.goalies];
    goalies.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'GOALIES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: goalies.map((goalie) {
            final isOnIce = false; // Goalies don't use the on-ice selection
            final isGoalScorer = widget.selectedGoalScorer == goalie;
            final isAssist1 = widget.selectedAssist1 == goalie;
            final isAssist2 = widget.selectedAssist2 == goalie;
            final isSelectedGoalie = widget.selectedGoalie == goalie;
            final isAbsent = _isPlayerAbsent(goalie);
            
            return _DraggablePlayerButton(
              player: goalie,
              isOnIce: isOnIce,
              isGoalScorer: isGoalScorer,
              isAssist1: isAssist1,
              isAssist2: isAssist2,
              isSelectedGoalie: isSelectedGoalie,
              isAbsent: isAbsent,
              width: _playerBoxWidth,
              height: _playerBoxHeight,
              jerseyFontSize: _jerseyFontSize,
              positionBadgeFontSize: _positionBadgeFontSize,
              iconSize: _iconSize,
              smallIconSize: _smallIconSize,
              onTap: () => _handlePlayerTap(goalie),
              onLongPress: () => _showPlayerRoleDialog(goalie),
              onDoubleTap: () => _showPlayerRoleDialog(goalie),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Count assists for status display
    int assistCount = 0;
    if (widget.selectedAssist1 != null) assistCount++;
    if (widget.selectedAssist2 != null) assistCount++;
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact status bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sports_hockey, 
                        color: (widget.selectedPlayersOnIce.length + (widget.selectedGoalie != null ? 1 : 0)) >= 3 && 
                               (widget.selectedPlayersOnIce.length + (widget.selectedGoalie != null ? 1 : 0)) <= 6 
                            ? Colors.green : Colors.red, 
                        size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'On Ice: ${widget.selectedPlayersOnIce.length + (widget.selectedGoalie != null ? 1 : 0)}/6',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (widget.selectedPlayersOnIce.length + (widget.selectedGoalie != null ? 1 : 0)) >= 3 && 
                                 (widget.selectedPlayersOnIce.length + (widget.selectedGoalie != null ? 1 : 0)) <= 6 
                              ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (widget.selectedGoalScorer != null) ...[
                        const Icon(Icons.sports_score, color: Colors.green, size: 14),
                        const SizedBox(width: 2),
                        const Text('Goal', style: TextStyle(fontSize: 10, color: Colors.green)),
                        const SizedBox(width: 8),
                      ],
                      if (assistCount > 0) ...[
                        const Icon(Icons.handshake, color: Colors.orange, size: 14),
                        const SizedBox(width: 2),
                        Text('Assist${assistCount > 1 ? 's' : ''} ($assistCount)', style: const TextStyle(fontSize: 10, color: Colors.orange)),
                        const SizedBox(width: 8),
                      ],
                      if (widget.selectedGoalie != null) ...[
                        const Icon(Icons.sports_hockey, color: Colors.purple, size: 14),
                        const SizedBox(width: 2),
                        const Text('Goalie', style: TextStyle(fontSize: 10, color: Colors.purple)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Forward lines
            _buildForwardLines(),
            
            const SizedBox(height: 8),
            
            // Defense lines
            _buildDefenseLines(),
            
            const SizedBox(height: 8),
            
            // Goalies section
            _buildGoalieSection(),
            
            const SizedBox(height: 6),
            
            // Clear skaters button (icon-only) - preserves goalie
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Reset Lines to Default',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _resetLineConfiguration,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
