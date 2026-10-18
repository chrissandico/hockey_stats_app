import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hockey_stats_app/widgets/share_dialog.dart';
import 'package:hockey_stats_app/widgets/goalie_stats_widget.dart';
import 'package:hockey_stats_app/widgets/score_summary_widget.dart';
import 'package:hockey_stats_app/services/stats_service.dart';
import 'package:hockey_stats_app/services/centralized_data_service.dart';
import 'package:hockey_stats_app/services/team_context_service.dart';

class _PlayerStatsRow {
  final Player player;
  final int goals;
  final int assists;
  final int points;
  final int plusMinus;
  final int pim;
  final OnIceShotStats onIceShots;
  final bool isAbsent;

  _PlayerStatsRow({
    required this.player,
    required this.goals,
    required this.assists,
    required this.points,
    required this.plusMinus,
    required this.pim,
    required this.onIceShots,
    required this.isAbsent,
  });
}

class ViewStatsScreen extends StatefulWidget {
  const ViewStatsScreen({super.key, this.gameId, required this.teamId});

  final String? gameId;
  final String teamId;

  @override
  State<ViewStatsScreen> createState() => _ViewStatsScreenState();
}

class _ViewStatsScreenState extends State<ViewStatsScreen> {
  late List<Player> players;
  late List<Player> goalies;
  final CentralizedDataService _centralizedDataService = CentralizedDataService();
  bool _isRefreshingNetwork = false;

  // Sorting, Period Filter & Attendance Filter State
  int? _sortColumnIndex = 4; // Default sort by Points (PTS)
  bool _sortAscending = false;
  int _selectedPeriodFilter = 0; // 0 = All, 1 = P1, 2 = P2, 3 = P3, 4 = OT
  bool _showPresentOnly = false;
  Set<String> _absentPlayerIds = {};

  @override
  void initState() {
    super.initState();
    final playersBox = Hive.box<Player>('players');
    final allPlayers = playersBox.values.where((player) => player.teamId == widget.teamId).toList();

    goalies = allPlayers.where((player) => player.position == 'G').toList();
    players = allPlayers.where((player) => player.position != 'G').toList();

    players.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    goalies.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));

    _loadAttendanceData();
  }

  void _loadAttendanceData() {
    if (widget.gameId == null) return;
    try {
      final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
      final attendance = attendanceBox.values
          .where((a) => a.gameId == widget.gameId && a.teamId == widget.teamId)
          .firstOrNull;

      if (attendance != null) {
        _absentPlayerIds = attendance.absentPlayerIds.toSet();
      }
    } catch (e) {
      print('Error loading attendance in ViewStatsScreen: $e');
    }
  }

  Future<void> _refreshStatsFromNetwork() async {
    if (!mounted || _isRefreshingNetwork) return;
    setState(() { _isRefreshingNetwork = true; });

    try {
      final success = await _centralizedDataService.forceRefreshFromSheets();

      // Reload players & goalies in case roster/jersey numbers changed in Sheets
      final playersBox = Hive.box<Player>('players');
      final allPlayers = playersBox.values.where((player) => player.teamId == widget.teamId).toList();

      if (mounted) {
        setState(() {
          goalies = allPlayers.where((player) => player.position == 'G').toList();
          players = allPlayers.where((player) => player.position != 'G').toList();
          players.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
          goalies.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Stats refreshed from Google Sheets' : 'Sync completed with local data'),
            backgroundColor: success ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error refreshing stats from network: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh stats: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isRefreshingNetwork = false; });
      }
    }
  }

  Future<void> _shareQuickCoachText(List<GameEvent> gameEvents) async {
    final gamesBox = Hive.box<Game>('games');
    final game = widget.gameId != null ? gamesBox.get(widget.gameId) : null;
    final opponentName = game?.opponent ?? 'Opponent';

    final teamContextService = TeamContextService();
    final teamName = await teamContextService.getCurrentTeamName();

    // Calculate score and period shots
    final Map<int, int> teamShots = {1: 0, 2: 0, 3: 0, 4: 0};
    final Map<int, int> oppShots = {1: 0, 2: 0, 3: 0, 4: 0};
    int teamGoals = 0;
    int oppGoals = 0;

    for (final event in gameEvents) {
      if (event.eventType == 'Shot') {
        final p = event.period.clamp(1, 4);
        if (event.team == widget.teamId) {
          teamShots[p] = (teamShots[p] ?? 0) + 1;
          if (event.isGoal == true) teamGoals++;
        } else if (event.team == 'opponent') {
          oppShots[p] = (oppShots[p] ?? 0) + 1;
          if (event.isGoal == true) oppGoals++;
        }
      }
    }

    final int teamTotalShots = teamShots.values.fold(0, (a, b) => a + b);
    final int oppTotalShots = oppShots.values.fold(0, (a, b) => a + b);

    // Build Goalie lines
    final List<String> goalieLines = [];
    for (final g in goalies) {
      final stats = StatsService.getGoalieStats(g, gameEvents, widget.teamId, teamGoalies: goalies);
      if (stats.shotsAgainst > 0) {
        final svPctStr = (stats.savePercentage * 100).toStringAsFixed(1);
        goalieLines.add('• #${g.jerseyNumber}: ${stats.saves}/${stats.shotsAgainst} SV ($svPctStr%)');
      }
    }

    final stStats = StatsService.getSpecialTeamsStats(gameEvents, widget.teamId);

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('🏒 Game Update: $teamName vs $opponentName');
    buffer.writeln('Score: $teamGoals - $oppGoals\n');
    buffer.writeln('Special Teams:');
    buffer.writeln('• Power Play: ${stStats.ppGoals}/${stStats.ppOpportunities} (${stStats.ppPercentage.toStringAsFixed(1)}%, ${stStats.ppShotsPerOpp.toStringAsFixed(1)} S/PP)');
    buffer.writeln('• Penalty Kill: ${stStats.pkSuccesses}/${stStats.pkOpportunities} (${stStats.pkPercentage.toStringAsFixed(1)}%, ${stStats.pkShotsAllowedPerOpp.toStringAsFixed(1)} SA/PK)');
    buffer.writeln('• Net ST Goals: ${stStats.netSpecialTeamsGoals > 0 ? "+${stStats.netSpecialTeamsGoals}" : stStats.netSpecialTeamsGoals}\n');
    buffer.writeln('Shots on Goal by Period:');
    buffer.writeln('• $teamName: P1: ${teamShots[1]} | P2: ${teamShots[2]} | P3: ${teamShots[3]}${(teamShots[4] ?? 0) > 0 ? " | OT: ${teamShots[4]}" : ""} (Total: $teamTotalShots)');
    buffer.writeln('• $opponentName: P1: ${oppShots[1]} | P2: ${oppShots[2]} | P3: ${oppShots[3]}${(oppShots[4] ?? 0) > 0 ? " | OT: ${oppShots[4]}" : ""} (Total: $oppTotalShots)\n');

    if (goalieLines.isNotEmpty) {
      buffer.writeln('Goalie Stats:');
      for (final line in goalieLines) {
        buffer.writeln(line);
      }
    }

    await Share.share(
      buffer.toString(),
      subject: '$teamName vs $opponentName Game Update',
    );
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<_PlayerStatsRow> _buildAndSortRows(List<GameEvent> rawEvents) {
    // Filter by Period if selected
    final events = _selectedPeriodFilter == 0
        ? rawEvents
        : rawEvents.where((e) => e.period == _selectedPeriodFilter).toList();

    // Filter by Attendance if present-only toggle is active
    final displayPlayers = _showPresentOnly
        ? players.where((p) => !_absentPlayerIds.contains(p.id)).toList()
        : players;

    // Pre-compute row values
    final rows = displayPlayers.map((p) {
      final isAbsent = _absentPlayerIds.contains(p.id);
      final g = StatsService.calculateGoals(p, events);
      final a = StatsService.calculateAssists(p, events);
      final pts = g + a;
      final pm = StatsService.calculatePlusMinus(p, events, widget.teamId);
      final pim = StatsService.calculatePenaltyMinutes(p, events);
      final onIceShots = StatsService.getOnIceShotStats(p, events, widget.teamId);

      return _PlayerStatsRow(
        player: p,
        goals: g,
        assists: a,
        points: pts,
        plusMinus: pm,
        pim: pim,
        onIceShots: onIceShots,
        isAbsent: isAbsent,
      );
    }).toList();

    // Perform sorting
    if (_sortColumnIndex != null) {
      rows.sort((a, b) {
        int cmp = 0;
        switch (_sortColumnIndex) {
          case 0: // #
            cmp = a.player.jerseyNumber.compareTo(b.player.jerseyNumber);
            break;
          case 1: // POS
            cmp = (a.player.position ?? '').compareTo(b.player.position ?? '');
            break;
          case 2: // G
            cmp = a.goals.compareTo(b.goals);
            break;
          case 3: // A
            cmp = a.assists.compareTo(b.assists);
            break;
          case 4: // PTS
            cmp = a.points.compareTo(b.points);
            break;
          case 5: // +/-
            cmp = a.plusMinus.compareTo(b.plusMinus);
            break;
          case 6: // PIM
            cmp = a.pim.compareTo(b.pim);
            break;
          case 7: // On-Ice SF/SA
            cmp = a.onIceShots.netShotsOnIce.compareTo(b.onIceShots.netShotsOnIce);
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final gameEventsBox = Hive.box<GameEvent>('gameEvents');

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Stats'),
        actions: [
          ValueListenableBuilder(
            valueListenable: gameEventsBox.listenable(),
            builder: (context, Box<GameEvent> box, _) {
              final events = box.values
                  .where((e) => widget.gameId == null || e.gameId == widget.gameId)
                  .toList();
              return IconButton(
                icon: const Icon(Icons.send_to_mobile),
                tooltip: 'Quick Text Update to Coach',
                onPressed: () => _shareQuickCoachText(events),
              );
            },
          ),
          IconButton(
            icon: _isRefreshingNetwork
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            tooltip: 'Refresh from Google Sheets',
            onPressed: _isRefreshingNetwork ? null : _refreshStatsFromNetwork,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final gamesBox = Hive.box<Game>('games');
              final game = gamesBox.get(widget.gameId);
              if (game == null) return;

              final events = gameEventsBox.values
                  .where((e) => widget.gameId == null || e.gameId == widget.gameId)
                  .toList();

              if (mounted) {
                await showDialog(
                  context: context,
                  builder: (context) => ShareDialog(
                    players: players,
                    gameEvents: events,
                    game: game,
                    teamId: widget.teamId,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: gameEventsBox.listenable(),
        builder: (context, Box<GameEvent> box, _) {
          final gameEvents = box.values
              .where((e) => widget.gameId == null || e.gameId == widget.gameId)
              .toList();

          final rows = _buildAndSortRows(gameEvents);

          // Find max points and max goals for leader highlighting
          int maxPts = 0;
          int maxGoals = 0;
          for (final r in rows) {
            if (!r.isAbsent) {
              if (r.points > maxPts) maxPts = r.points;
              if (r.goals > maxGoals) maxGoals = r.goals;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListView(
              children: <Widget>[
                ScoreSummaryWidget(
                  gameEvents: gameEvents,
                  teamId: widget.teamId,
                  gameId: widget.gameId,
                  isLoading: _isRefreshingNetwork,
                ),
                const SizedBox(height: 12.0),

                // Period Filter & Present Only Toggle Bar
                Row(
                  children: [
                    const Text('Period: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        _buildFilterChip('All', 0),
                        _buildFilterChip('P1', 1),
                        _buildFilterChip('P2', 2),
                        _buildFilterChip('P3', 3),
                        _buildFilterChip('OT', 4),
                      ],
                    ),
                    const Spacer(),
                    FilterChip(
                      label: Text(_showPresentOnly ? 'Present Only' : 'All Roster', style: const TextStyle(fontSize: 11)),
                      selected: _showPresentOnly,
                      selectedColor: Colors.purple.shade700,
                      labelStyle: TextStyle(color: _showPresentOnly ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        setState(() {
                          _showPresentOnly = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),

                Row(
                  children: [
                    const Text('Individual Player Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_isRefreshingNetwork)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10.0),

                // Sticky Column Data Table
                SizedBox(
                  height: (rows.length + 1) * 48.0 + 20,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dataTableTheme: DataTableThemeData(
                        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade900),
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    child: DataTable2(
                      fixedLeftColumns: 2, // Freezes Jersey # and POS on the left!
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                      columnSpacing: 10.0,
                      headingRowHeight: 46,
                      dataRowHeight: 44,
                      columns: [
                        DataColumn2(
                          label: const Text('#'),
                          size: ColumnSize.S,
                          onSort: _onSort,
                        ),
                        DataColumn2(
                          label: const Text('POS'),
                          size: ColumnSize.S,
                          onSort: _onSort,
                        ),
                        DataColumn2(
                          label: const Text('G'),
                          numeric: true,
                          size: ColumnSize.S,
                          onSort: _onSort,
                        ),
                        DataColumn2(
                          label: const Text('A'),
                          numeric: true,
                          size: ColumnSize.S,
                          onSort: _onSort,
                        ),
                        DataColumn2(
                          label: const Text('PTS'),
                          numeric: true,
                          size: ColumnSize.S,
                          onSort: _onSort,
                        ),
                        DataColumn2(
                          label: const Text('+/-'),
                          numeric: true,
                          size: ColumnSize.S,
                          onSort: _onSort,
                        ),
                        DataColumn2(
                          label: const Text('PIM'),
                          numeric: true,
                          size: ColumnSize.M, // Sized M so PIM header isn't clipped
                          onSort: _onSort,
                        ),
                        DataColumn2(
                          label: const Text('SF/SA'),
                          numeric: true,
                          size: ColumnSize.M,
                          onSort: _onSort,
                        ),
                      ],
                      rows: rows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final r = entry.value;

                        final isTopScorer = !r.isAbsent && maxPts > 0 && r.points == maxPts;
                        final isTopGoalScorer = !r.isAbsent && maxGoals > 0 && r.goals == maxGoals;

                        final textColor = r.isAbsent ? Colors.grey.shade600 : Colors.black87;

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (r.isAbsent) return Colors.grey.shade200;
                              if (states.contains(WidgetState.hovered)) {
                                return Colors.blue.withOpacity(0.1);
                              }
                              return index.isEven ? Colors.grey.shade100 : null;
                            },
                          ),
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Text(
                                    r.player.jerseyNumber.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      decoration: r.isAbsent ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (isTopScorer)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 2.0),
                                      child: Icon(Icons.star, size: 12, color: Colors.amber),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                r.isAbsent ? '${r.player.position ?? 'N/A'} (DNP)' : (r.player.position ?? 'N/A'),
                                style: TextStyle(
                                  fontSize: r.isAbsent ? 11 : 13,
                                  color: r.isAbsent ? Colors.grey.shade600 : Colors.black87,
                                  fontStyle: r.isAbsent ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                r.goals.toString(),
                                style: TextStyle(
                                  fontWeight: isTopGoalScorer ? FontWeight.bold : FontWeight.normal,
                                  color: isTopGoalScorer ? Colors.amber.shade900 : textColor,
                                ),
                              ),
                            ),
                            DataCell(Text(r.assists.toString(), style: TextStyle(color: textColor))),
                            DataCell(
                              Text(
                                r.points.toString(),
                                style: TextStyle(
                                  fontWeight: isTopScorer ? FontWeight.bold : FontWeight.normal,
                                  color: isTopScorer ? Colors.amber.shade900 : textColor,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                r.plusMinus.toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: r.isAbsent
                                      ? Colors.grey.shade600
                                      : (r.plusMinus > 0 ? Colors.green.shade700 : (r.plusMinus < 0 ? Colors.red.shade700 : null)),
                                ),
                              ),
                            ),
                            DataCell(Text(r.pim.toString(), style: TextStyle(color: textColor))),
                            DataCell(
                              Text(
                                '${r.onIceShots.shotsForOnIce}/${r.onIceShots.shotsAgainstOnIce}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: r.isAbsent
                                      ? Colors.grey.shade600
                                      : (r.onIceShots.netShotsOnIce > 0
                                          ? Colors.green.shade700
                                          : (r.onIceShots.netShotsOnIce < 0 ? Colors.red.shade700 : textColor)),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (goalies.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  GoalieStatsWidget(
                    goalies: goalies,
                    gameEvents: gameEvents,
                    teamId: widget.teamId,
                    isLoading: _isRefreshingNetwork,
                    showTitle: true,
                    showLegend: false,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, int value) {
    final isSelected = _selectedPeriodFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      selectedColor: Colors.blue.shade700,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriodFilter = value;
          });
        }
      },
    );
  }
}
