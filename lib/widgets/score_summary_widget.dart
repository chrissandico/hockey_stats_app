import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ScoreSummaryWidget extends StatelessWidget {
  final List<GameEvent> gameEvents;
  final String teamId;
  final String? gameId;
  final bool isLoading;

  const ScoreSummaryWidget({
    super.key,
    required this.gameEvents,
    required this.teamId,
    this.gameId,
    this.isLoading = false,
  });

  Map<String, dynamic> _calculatePeriodScoring() {
    // Calculate goals and shots by period for both teams
    final Map<int, int> yourTeamGoalsByPeriod = {};
    final Map<int, int> opponentGoalsByPeriod = {};
    final Map<int, int> yourTeamShotsByPeriod = {};
    final Map<int, int> opponentShotsByPeriod = {};
    
    // Initialize periods 1-4 (including OT)
    for (int period = 1; period <= 4; period++) {
      yourTeamGoalsByPeriod[period] = 0;
      opponentGoalsByPeriod[period] = 0;
      yourTeamShotsByPeriod[period] = 0;
      opponentShotsByPeriod[period] = 0;
    }
    
    // Count goals and shots by period
    for (final event in gameEvents) {
      if (event.eventType == 'Shot') {
        final period = event.period;
        if (period >= 1 && period <= 4) {
          if (event.team == teamId) {
            yourTeamShotsByPeriod[period] = (yourTeamShotsByPeriod[period] ?? 0) + 1;
            if (event.isGoal == true) {
              yourTeamGoalsByPeriod[period] = (yourTeamGoalsByPeriod[period] ?? 0) + 1;
            }
          } else if (event.team == 'opponent') {
            opponentShotsByPeriod[period] = (opponentShotsByPeriod[period] ?? 0) + 1;
            if (event.isGoal == true) {
              opponentGoalsByPeriod[period] = (opponentGoalsByPeriod[period] ?? 0) + 1;
            }
          }
        }
      }
    }
    
    // Calculate totals
    final yourTeamTotal = yourTeamGoalsByPeriod.values.fold(0, (a, b) => a + b);
    final opponentTotal = opponentGoalsByPeriod.values.fold(0, (a, b) => a + b);
    final yourTeamShotsTotal = yourTeamShotsByPeriod.values.fold(0, (a, b) => a + b);
    final opponentShotsTotal = opponentShotsByPeriod.values.fold(0, (a, b) => a + b);
    
    // Determine which periods to show (always show 1-3, show OT only if there were goals or shots)
    final showOT = (yourTeamGoalsByPeriod[4] ?? 0) > 0 || (opponentGoalsByPeriod[4] ?? 0) > 0 ||
                   (yourTeamShotsByPeriod[4] ?? 0) > 0 || (opponentShotsByPeriod[4] ?? 0) > 0;
    
    // Get team names
    String yourTeamName = 'Your Team';
    String opponentName = 'Opponent';
    
    // Try to get opponent name from game data
    if (gameId != null) {
      final gamesBox = Hive.box<Game>('games');
      final game = gamesBox.get(gameId);
      if (game != null) {
        opponentName = game.opponent;
      }
    }
    
    return {
      'yourTeamGoalsByPeriod': yourTeamGoalsByPeriod,
      'opponentGoalsByPeriod': opponentGoalsByPeriod,
      'yourTeamShotsByPeriod': yourTeamShotsByPeriod,
      'opponentShotsByPeriod': opponentShotsByPeriod,
      'yourTeamTotal': yourTeamTotal,
      'opponentTotal': opponentTotal,
      'yourTeamShotsTotal': yourTeamShotsTotal,
      'opponentShotsTotal': opponentShotsTotal,
      'showOT': showOT,
      'yourTeamName': yourTeamName,
      'opponentName': opponentName,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final scoringData = _calculatePeriodScoring();
    final yourTeamGoalsByPeriod = scoringData['yourTeamGoalsByPeriod'] as Map<int, int>;
    final opponentGoalsByPeriod = scoringData['opponentGoalsByPeriod'] as Map<int, int>;
    final yourTeamShotsByPeriod = scoringData['yourTeamShotsByPeriod'] as Map<int, int>;
    final opponentShotsByPeriod = scoringData['opponentShotsByPeriod'] as Map<int, int>;
    final yourTeamTotal = scoringData['yourTeamTotal'] as int;
    final opponentTotal = scoringData['opponentTotal'] as int;
    final yourTeamShotsTotal = scoringData['yourTeamShotsTotal'] as int;
    final opponentShotsTotal = scoringData['opponentShotsTotal'] as int;
    final showOT = scoringData['showOT'] as bool;
    final yourTeamName = scoringData['yourTeamName'] as String;
    final opponentName = scoringData['opponentName'] as String;

    // If no goals were scored, show a simple message
    if (yourTeamTotal == 0 && opponentTotal == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Score Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Final Score: 0 - 0',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'No goals scored in this game.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Score Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Final: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '$yourTeamTotal',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text(
                        ' - ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$opponentTotal',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Period-by-period table using simple Table widget
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                  columnWidths: showOT ? {
                    0: const FlexColumnWidth(2.5), // Team
                    1: const FlexColumnWidth(1), // 1
                    2: const FlexColumnWidth(1), // 2
                    3: const FlexColumnWidth(1), // 3
                    4: const FlexColumnWidth(1), // OT
                    5: const FlexColumnWidth(1), // T
                  } : {
                    0: const FlexColumnWidth(2.5), // Team
                    1: const FlexColumnWidth(1), // 1
                    2: const FlexColumnWidth(1), // 2
                    3: const FlexColumnWidth(1), // 3
                    4: const FlexColumnWidth(1), // T
                  },
                  children: [
                    // Header row
                    TableRow(
                      decoration: const BoxDecoration(color: Colors.black),
                      children: showOT ? [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Team',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '2',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '3',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              'OT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              'T',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ] : [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Team',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '2',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '3',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              'T',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Your team row
                    TableRow(
                      children: showOT ? [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            yourTeamName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${yourTeamGoalsByPeriod[1] ?? 0} [${yourTeamShotsByPeriod[1] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${yourTeamGoalsByPeriod[2] ?? 0} [${yourTeamShotsByPeriod[2] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${yourTeamGoalsByPeriod[3] ?? 0} [${yourTeamShotsByPeriod[3] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${yourTeamGoalsByPeriod[4] ?? 0} [${yourTeamShotsByPeriod[4] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$yourTeamTotal [$yourTeamShotsTotal]',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] : [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            yourTeamName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${yourTeamGoalsByPeriod[1] ?? 0} [${yourTeamShotsByPeriod[1] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${yourTeamGoalsByPeriod[2] ?? 0} [${yourTeamShotsByPeriod[2] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${yourTeamGoalsByPeriod[3] ?? 0} [${yourTeamShotsByPeriod[3] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$yourTeamTotal [$yourTeamShotsTotal]',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Opponent team row
                    TableRow(
                      children: showOT ? [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            opponentName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${opponentGoalsByPeriod[1] ?? 0} [${opponentShotsByPeriod[1] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${opponentGoalsByPeriod[2] ?? 0} [${opponentShotsByPeriod[2] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${opponentGoalsByPeriod[3] ?? 0} [${opponentShotsByPeriod[3] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${opponentGoalsByPeriod[4] ?? 0} [${opponentShotsByPeriod[4] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$opponentTotal [$opponentShotsTotal]',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] : [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            opponentName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${opponentGoalsByPeriod[1] ?? 0} [${opponentShotsByPeriod[1] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${opponentGoalsByPeriod[2] ?? 0} [${opponentShotsByPeriod[2] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              '${opponentGoalsByPeriod[3] ?? 0} [${opponentShotsByPeriod[3] ?? 0}]',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$opponentTotal [$opponentShotsTotal]',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
