import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/stats_service.dart';
import 'package:intl/intl.dart';

class ShotsAgainstDialog extends StatefulWidget {
  final List<Player> goalies;
  final List<GameEvent> gameEvents;
  final String teamId;
  final Player? initialSelectedGoalie;

  const ShotsAgainstDialog({
    super.key,
    required this.goalies,
    required this.gameEvents,
    required this.teamId,
    this.initialSelectedGoalie,
  });

  @override
  State<ShotsAgainstDialog> createState() => _ShotsAgainstDialogState();
}

class _ShotsAgainstDialogState extends State<ShotsAgainstDialog> {
  late Box<Player> _playersBox;
  Player? _selectedGoalie;
  bool _isOpponentGoalie = false;
  bool _filterGoalsOnly = false;
  int _selectedPeriod = 0; // 0 = All

  @override
  void initState() {
    super.initState();
    _playersBox = Hive.box<Player>('players');

    if (widget.initialSelectedGoalie != null) {
      _selectedGoalie = widget.initialSelectedGoalie;
    } else if (widget.goalies.isNotEmpty) {
      _selectedGoalie = widget.goalies.first;
    }
  }

  String _getPlayerJerseyText(String playerId) {
    if (playerId.isEmpty) return 'N/A';
    try {
      final p = _playersBox.values.firstWhere((player) => player.id == playerId);
      return '#${p.jerseyNumber}';
    } catch (_) {
      return 'Unknown';
    }
  }

  Player? _findPlayer(String playerId) {
    try {
      return _playersBox.values.firstWhere((p) => p.id == playerId);
    } catch (_) {
      return null;
    }
  }

  String _formatTime(DateTime timestamp, String? clockTime) {
    if (clockTime != null && clockTime.isNotEmpty) {
      return clockTime;
    }
    return DateFormat('h:mm a').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    // Determine target shots
    List<GameEvent> shots;
    if (_isOpponentGoalie) {
      shots = StatsService.getShotsFacedByGoalie(
        Player(id: 'opponent_g', jerseyNumber: 0, position: 'G'),
        widget.gameEvents,
        widget.teamId,
        isOpponentGoalie: true,
      );
    } else if (_selectedGoalie != null) {
      shots = StatsService.getShotsFacedByGoalie(
        _selectedGoalie!,
        widget.gameEvents,
        widget.teamId,
        teamGoalies: widget.goalies,
      );
    } else {
      shots = [];
    }

    // Apply filters
    if (_selectedPeriod > 0) {
      shots = shots.where((e) => e.period == _selectedPeriod).toList();
    }

    if (_filterGoalsOnly) {
      shots = shots.where((e) => e.isGoal == true).toList();
    }

    // Sort chronologically (most recent first)
    shots.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Compute stats
    final totalShots = shots.length;
    final goalsAgainst = shots.where((e) => e.isGoal == true).length;
    final saves = totalShots - goalsAgainst;
    final svPct = totalShots > 0 ? (saves / totalShots) * 100 : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600),
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.purple, size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Shots Faced & On-Ice Lineup',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),

            // Goalie Selector Row
            Row(
              children: [
                const Text('Goalie: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _isOpponentGoalie ? 'OPP' : (_selectedGoalie?.id ?? ''),
                        items: [
                          ...widget.goalies.map((g) => DropdownMenuItem<String>(
                                value: g.id,
                                child: Text('#${g.jerseyNumber} (Home Goalie)'),
                              )),
                          const DropdownMenuItem<String>(
                            value: 'OPP',
                            child: Text('Opponent Goalie'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            if (val == 'OPP') {
                              _isOpponentGoalie = true;
                              _selectedGoalie = null;
                            } else {
                              _isOpponentGoalie = false;
                              _selectedGoalie = widget.goalies.firstWhere((g) => g.id == val);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stat Summary Cards
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryCol('Shots', '$totalShots'),
                  _buildSummaryCol('Saves', '$saves'),
                  _buildSummaryCol('Goals', '$goalsAgainst', isWarning: goalsAgainst > 0),
                  _buildSummaryCol('Save %', '${svPct.toStringAsFixed(1)}%'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Period Filter & Toggle Buttons Bar
            Row(
              children: [
                Wrap(
                  spacing: 4,
                  children: [
                    _buildPeriodChip('All', 0),
                    _buildPeriodChip('P1', 1),
                    _buildPeriodChip('P2', 2),
                    _buildPeriodChip('P3', 3),
                    _buildPeriodChip('OT', 4),
                  ],
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('Goals Only', style: TextStyle(fontSize: 11)),
                  selected: _filterGoalsOnly,
                  selectedColor: Colors.red.shade700,
                  labelStyle: TextStyle(
                    color: _filterGoalsOnly ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) {
                    setState(() {
                      _filterGoalsOnly = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Shots List View
            Expanded(
              child: shots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_hockey, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _filterGoalsOnly ? 'No goals logged for this selection.' : 'No shots logged for this goalie yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: shots.length,
                      itemBuilder: (context, index) {
                        final event = shots[index];
                        final isGoal = event.isGoal == true;
                        final isYourTeamShot = event.team == widget.teamId;

                        // Shooter label
                        String shooterText = 'Opponent Shooter';
                        if (isYourTeamShot) {
                          shooterText = _getPlayerJerseyText(event.primaryPlayerId);
                        }

                        // Situation text
                        String sitText = '';
                        if (event.goalSituation == GoalSituation.powerPlay) {
                          sitText = ' (PP)';
                        } else if (event.goalSituation == GoalSituation.shortHanded) {
                          sitText = ' (PK)';
                        }

                        // On-ice players list
                        final onIceIds = event.yourTeamPlayersOnIce ?? [];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isGoal ? Colors.red.shade700 : Colors.blue.shade700,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isGoal ? 'GOAL' : 'SAVE',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'P${event.period} • ${_formatTime(event.timestamp, event.gameClockTime)}$sitText',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'By: $shooterText',
                                      style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // On-ice Lineup Section
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'On Ice: ',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                    Expanded(
                                      child: onIceIds.isEmpty
                                          ? Text(
                                              'No on-ice lineup recorded',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                            )
                                          : Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: onIceIds.map((pId) {
                                                final p = _findPlayer(pId);
                                                final label = p != null
                                                    ? '#${p.jerseyNumber}${p.position != null ? " (${p.position})" : ""}'
                                                    : 'Unknown';
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                  ),
                                                  child: Text(
                                                    label,
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCol(String title, String value, {bool isWarning = false}) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.red.shade800 : Colors.purple.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, int value) {
    final isSelected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: isSelected,
      selectedColor: Colors.purple.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = value;
          });
        }
      },
    );
  }
}
