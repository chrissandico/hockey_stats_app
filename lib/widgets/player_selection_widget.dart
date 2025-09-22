import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';

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
  
  // Helper methods for position detection
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
  
  // Check if a player is absent
  bool _isPlayerAbsent(Player player) {
    return widget.absentPlayerIds.contains(player.id);
  }
  
  Widget _buildRoleIndicator(String label, IconData icon, Color color, int count, [String? subtitle]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Color _getPlayerBackgroundColor(Player player) {
    final isOnIce = widget.selectedPlayersOnIce.contains(player);
    final isGoalScorer = widget.selectedGoalScorer == player;
    final isAssist1 = widget.selectedAssist1 == player;
    final isAssist2 = widget.selectedAssist2 == player;
    final isSelectedGoalie = widget.selectedGoalie == player;
    final isAbsent = _isPlayerAbsent(player);
    
    if (isAbsent) return Colors.grey.withOpacity(0.3);
    if (isGoalScorer) return Colors.green.withOpacity(0.2);
    if (isAssist1 || isAssist2) return Colors.orange.withOpacity(0.2);
    if (isSelectedGoalie) return Colors.purple.withOpacity(0.2);
    if (isOnIce) return Colors.blue.withOpacity(0.2);
    return Colors.grey.withOpacity(0.1);
  }
  
  Color _getPlayerBorderColor(Player player) {
    final isOnIce = widget.selectedPlayersOnIce.contains(player);
    final isGoalScorer = widget.selectedGoalScorer == player;
    final isAssist1 = widget.selectedAssist1 == player;
    final isAssist2 = widget.selectedAssist2 == player;
    final isSelectedGoalie = widget.selectedGoalie == player;
    final isAbsent = _isPlayerAbsent(player);
    
    if (isAbsent) return Colors.grey;
    if (isGoalScorer) return Colors.green;
    if (isAssist1 || isAssist2) return Colors.orange;
    if (isSelectedGoalie) return Colors.purple;
    if (isOnIce) return Colors.blue;
    return Colors.grey.withOpacity(0.5);
  }
  
  Color _getPlayerTextColor(Player player) {
    final isOnIce = widget.selectedPlayersOnIce.contains(player);
    final isGoalScorer = widget.selectedGoalScorer == player;
    final isAssist1 = widget.selectedAssist1 == player;
    final isAssist2 = widget.selectedAssist2 == player;
    final isSelectedGoalie = widget.selectedGoalie == player;
    final isAbsent = _isPlayerAbsent(player);
    
    if (isAbsent) return Colors.grey;
    if (isGoalScorer) return Colors.green;
    if (isAssist1 || isAssist2) return Colors.orange;
    if (isSelectedGoalie) return Colors.purple;
    if (isOnIce) return Colors.blue;
    return Colors.black87;
  }
  
  void _handlePlayerTap(Player player) {
    // Don't allow selecting absent players
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
      // Toggle skater on ice - enforce hockey rule: max 6 total players (including goalie)
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

  void _showPlayerRoleDialog(Player player) {
    final isOnIce = widget.selectedPlayersOnIce.contains(player);
    final isGoalScorer = widget.selectedGoalScorer == player;
    final isAssist1 = widget.selectedAssist1 == player;
    final isAssist2 = widget.selectedAssist2 == player;
    final isSelectedGoalie = widget.selectedGoalie == player;
    final isAbsent = _isPlayerAbsent(player);
    final isGoalie = _isGoalie(player);
    
    // Only show dialog for selected players
    if (!isOnIce && !isSelectedGoalie) {
      return;
    }
    
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
                // Skater role assignment options
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
                  leading: const Icon(Icons.handshake, color: Colors.orange),
                  title: const Text('1st Assist'),
                  trailing: Switch(
                    value: isAssist1,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      if (value) {
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
                    leading: const Icon(Icons.handshake_outlined, color: Colors.orange),
                    title: const Text('2nd Assist'),
                    trailing: Switch(
                      value: isAssist2,
                      activeColor: Colors.orange,
                      onChanged: (value) {
                        if (value) {
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

  Widget _buildPositionSection({
    required String title,
    required List<Player> players,
    required int columns,
    required Color color,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 1.0, // Consistent square buttons for all positions
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final isOnIce = widget.selectedPlayersOnIce.contains(player);
        final isGoalScorer = widget.selectedGoalScorer == player;
        final isAssist1 = widget.selectedAssist1 == player;
        final isAssist2 = widget.selectedAssist2 == player;
        final isSelectedGoalie = widget.selectedGoalie == player;
        final isAbsent = _isPlayerAbsent(player);
        final isForward = _isForward(player);
        final isDefenseman = _isDefenseman(player);
        final isGoalie = _isGoalie(player);
        
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
        
        return GestureDetector(
          onTap: () => _handlePlayerTap(player),
          onLongPress: () => _showPlayerRoleDialog(player),
          child: Container(
            decoration: BoxDecoration(
              color: _getPlayerBackgroundColor(player),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getPlayerBorderColor(player),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '#${player.jerseyNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getPlayerTextColor(player),
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
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Role indicators
                if (isGoalScorer)
                  const Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(
                      Icons.sports_score,
                      size: 14,
                      color: Colors.green,
                    ),
                  ),
                if (isAssist1)
                  const Positioned(
                    bottom: 2,
                    right: 2,
                    child: Icon(
                      Icons.handshake,
                      size: 14,
                      color: Colors.orange,
                    ),
                  ),
                if (isAssist2)
                  const Positioned(
                    bottom: 2,
                    right: 14,
                    child: Icon(
                      Icons.handshake_outlined,
                      size: 12,
                      color: Colors.orange,
                    ),
                  ),
                if (isSelectedGoalie)
                  const Positioned(
                    bottom: 2,
                    right: 2,
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.purple,
                    ),
                  ),
                if (isAbsent)
                  const Positioned(
                    bottom: 2,
                    left: 2,
                    child: Icon(
                      Icons.person_off,
                      size: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort players by position: Forwards first, then Defensemen, then Goalies
    // Within each position, sort by jersey number ascending
    
    // Get forwards and sort by jersey number
    final forwards = widget.players.where((player) => 
      player.position == 'C' || 
      player.position == 'LW' || 
      player.position == 'RW' ||
      player.position == 'F'
    ).toList();
    forwards.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Get defensemen and sort by jersey number
    final defensemen = widget.players.where((player) => 
      player.position == 'D' || 
      player.position == 'LD' || 
      player.position == 'RD'
    ).toList();
    defensemen.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Get goalies and sort by jersey number
    final goalies = [...widget.goalies];
    goalies.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    
    // Combine in order: Forwards → Defensemen → Goalies
    final allPlayers = [...forwards, ...defensemen, ...goalies];
    
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
            
            // Position-based layout with separate sections (no headings, minimal spacing)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Forwards Section
                if (forwards.isNotEmpty) ...[
                  _buildPositionSection(
                    title: 'Forwards',
                    players: forwards,
                    columns: 6,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 6),
                ],
                
                // Defensemen Section
                if (defensemen.isNotEmpty) ...[
                  _buildPositionSection(
                    title: 'Defense',
                    players: defensemen,
                    columns: defensemen.length <= 4 ? 4 : 6,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 6),
                ],
                
                // Goalies Section
                if (goalies.isNotEmpty) ...[
                  _buildPositionSection(
                    title: 'Goalies',
                    players: goalies,
                    columns: 6, // Use same column count as forwards for consistent sizing
                    color: Colors.purple,
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Clear all button (icon-only)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 18),
                  tooltip: 'Clear All',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    widget.onPlayersOnIceChanged([]);
                    widget.onGoalScorerChanged(null);
                    widget.onAssist1Changed(null);
                    if (widget.onAssist2Changed != null) {
                      widget.onAssist2Changed!(null);
                    }
                    widget.onGoalieChanged(null);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
