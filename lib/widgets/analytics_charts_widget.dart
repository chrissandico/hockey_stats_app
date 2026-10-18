import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/stats_service.dart';

class AnalyticsChartsWidget extends StatelessWidget {
  final List<GameEvent> gameEvents;
  final List<Player> players;
  final String teamId;

  const AnalyticsChartsWidget({
    super.key,
    required this.gameEvents,
    required this.players,
    required this.teamId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildShotsAndGoalsByPeriodCard(context),
        const SizedBox(height: 16),
        _buildSpecialTeamsCard(context),
        const SizedBox(height: 16),
        _buildTopScorersLeaderboard(context),
      ],
    );
  }

  /// Period-by-Period Shots & Goals Bar Chart
  Widget _buildShotsAndGoalsByPeriodCard(BuildContext context) {
    final Map<int, int> shotsByPeriod = {1: 0, 2: 0, 3: 0, 4: 0};
    final Map<int, int> goalsByPeriod = {1: 0, 2: 0, 3: 0, 4: 0};

    for (final event in gameEvents) {
      if (event.eventType == 'Shot') {
        final p = event.period.clamp(1, 4);
        shotsByPeriod[p] = (shotsByPeriod[p] ?? 0) + 1;
        if (event.isGoal == true) {
          goalsByPeriod[p] = (goalsByPeriod[p] ?? 0) + 1;
        }
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blueGrey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shots & Goals by Period',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (shotsByPeriod.values.fold(0, (a, b) => a > b ? a : b) + 5).toDouble(),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 1:
                              return const Text('P1', style: TextStyle(color: Colors.white70));
                            case 2:
                              return const Text('P2', style: TextStyle(color: Colors.white70));
                            case 3:
                              return const Text('P3', style: TextStyle(color: Colors.white70));
                            case 4:
                              return const Text('OT', style: TextStyle(color: Colors.white70));
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [1, 2, 3, 4].map((p) {
                    return BarChartGroupData(
                      x: p,
                      barRods: [
                        BarChartRodData(
                          toY: (shotsByPeriod[p] ?? 0).toDouble(),
                          color: Colors.blueAccent,
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: (goalsByPeriod[p] ?? 0).toDouble(),
                          color: Colors.greenAccent,
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIndicator(Colors.blueAccent, 'Shots'),
                const SizedBox(width: 24),
                _buildIndicator(Colors.greenAccent, 'Goals'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Special Teams Performance Ring Charts (Power Play % & Penalty Kill %)
  Widget _buildSpecialTeamsCard(BuildContext context) {
    final stStats = StatsService.getSpecialTeamsStats(gameEvents, teamId);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blueGrey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Special Teams Efficiency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stStats.combinedSpecialTeamsIndex >= 100 ? Colors.green.shade800 : Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ST Index: ${stStats.combinedSpecialTeamsIndex.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRingChart(
                  'Power Play %',
                  stStats.ppPercentage,
                  Colors.amber,
                  '${stStats.ppGoals} / ${stStats.ppOpportunities} PP (${stStats.ppShotsPerOpp.toStringAsFixed(1)} S/PP)',
                ),
                _buildRingChart(
                  'Penalty Kill %',
                  stStats.pkPercentage,
                  Colors.cyanAccent,
                  '${stStats.pkSuccesses} / ${stStats.pkOpportunities} PK (${stStats.pkShotsAllowedPerOpp.toStringAsFixed(1)} SA/PK)',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    'Net ST Goals: ${stStats.netSpecialTeamsGoals > 0 ? "+${stStats.netSpecialTeamsGoals}" : stStats.netSpecialTeamsGoals}',
                    style: TextStyle(
                      color: stStats.netSpecialTeamsGoals > 0 ? Colors.greenAccent : (stStats.netSpecialTeamsGoals < 0 ? Colors.redAccent : Colors.white70),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Discipline: ${stStats.netPenalties > 0 ? "+${stStats.netPenalties} Net PP" : "${stStats.netPenalties} Net PP"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingChart(String title, double percentage, Color color, String subtitle) {
    return Column(
      children: [
        SizedBox(
          height: 100,
          width: 100,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 36,
                  sections: [
                    PieChartSectionData(
                      color: color,
                      value: percentage,
                      title: '',
                      radius: 12,
                    ),
                    PieChartSectionData(
                      color: Colors.white10,
                      value: (100 - percentage).clamp(0, 100),
                      title: '',
                      radius: 12,
                    ),
                  ],
                ),
              ),
              Center(
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  /// Top Scorers & Plus/Minus Leaders
  Widget _buildTopScorersLeaderboard(BuildContext context) {
    final List<PlayerSeasonStats> statsList = players.map((p) {
      return StatsService.getPlayerStats(p, gameEvents, teamId);
    }).toList();

    // Sort by Points
    statsList.sort((a, b) => b.points.compareTo(a.points));
    final topScorers = statsList.take(5).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blueGrey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Points Leaders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...topScorers.map((s) {
              final player = players.firstWhere((p) => p.id == s.playerId, orElse: () => Player(id: s.playerId, jerseyNumber: s.playerJerseyNumber));
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blue.shade700,
                      child: Text('#${player.jerseyNumber}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.position != null ? '${player.position}' : 'Player',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${s.goals}G  ${s.assists}A  (${s.points} PTS)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${s.plusMinus > 0 ? "+${s.plusMinus}" : s.plusMinus}',
                      style: TextStyle(
                        color: s.plusMinus > 0 ? Colors.greenAccent : (s.plusMinus < 0 ? Colors.redAccent : Colors.white54),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
