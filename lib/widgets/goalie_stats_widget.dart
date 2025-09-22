import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/stats_service.dart';
import 'package:data_table_2/data_table_2.dart';

class GoalieStatsWidget extends StatelessWidget {
  final List<Player> goalies;
  final List<GameEvent> gameEvents;
  final String teamId;
  final bool isLoading;
  final bool showTitle;
  final bool showLegend;

  const GoalieStatsWidget({
    super.key,
    required this.goalies,
    required this.gameEvents,
    required this.teamId,
    this.isLoading = false,
    this.showTitle = true,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    if (goalies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Row(
            children: [
              const Text(
                'Goalie Stats',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16.0),
        ],
        
        SizedBox(
          height: (goalies.length + 1) * 56.0 + 20,
          child: Theme(
            data: Theme.of(context).copyWith(
              dataTableTheme: DataTableThemeData(
                headingRowColor: WidgetStateProperty.all(Colors.purple),
                headingTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            child: DataTable2(
              border: TableBorder.all(color: Colors.grey.shade300, width: 1),
              columnSpacing: 15.0,
              headingRowHeight: 50,
              dataRowHeight: 45,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('SA'), numeric: true),
                DataColumn(label: Text('GA'), numeric: true),
                DataColumn(label: Text('SV'), numeric: true),
                DataColumn(label: Text('SV%'), numeric: true),
                DataColumn(label: Text('GP'), numeric: true),
              ],
              rows: goalies.asMap().entries.map((entry) {
                final index = entry.key;
                final goalie = entry.value;
                final goalieStats = StatsService.getGoalieStats(goalie, gameEvents, teamId);
                
                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.hovered)) {
                        return Colors.purple.withOpacity(0.1);
                      }
                      return index.isEven ? Colors.grey.shade100 : null;
                    },
                  ),
                  cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          goalie.jerseyNumber.toString(),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          goalieStats.shotsAgainst.toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          goalieStats.goalsAgainst.toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          goalieStats.saves.toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          goalieStats.savePercentage > 0 
                              ? '${(goalieStats.savePercentage * 100).toStringAsFixed(1)}%'
                              : '0.0%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _getSavePercentageColor(goalieStats.savePercentage),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          goalieStats.gamesPlayed.toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        
        if (showLegend) ...[
          const SizedBox(height: 16.0),
          Card(
            color: Colors.purple.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Goalie Stats Legend:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text('SA = Shots Against', style: TextStyle(fontSize: 12)),
                  const Text('GA = Goals Against', style: TextStyle(fontSize: 12)),
                  const Text('SV = Saves', style: TextStyle(fontSize: 12)),
                  const Text('SV% = Save Percentage', style: TextStyle(fontSize: 12)),
                  const Text('GP = Games Played', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color? _getSavePercentageColor(double savePercentage) {
    if (savePercentage >= 0.9) {
      return Colors.green;
    } else if (savePercentage >= 0.8) {
      return Colors.orange;
    } else if (savePercentage > 0) {
      return Colors.red;
    }
    return null;
  }
}
