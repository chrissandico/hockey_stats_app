import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/team_context_service.dart';
import 'package:hockey_stats_app/services/stats_service.dart';
import 'package:hockey_stats_app/services/centralized_data_service.dart';

class PdfService {
  final TeamContextService _teamContextService = TeamContextService();
  final CentralizedDataService _centralizedDataService = CentralizedDataService();

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Helper method to convert game type codes to readable text
  String _getGameTypeText(String gameType) {
    switch (gameType.toUpperCase()) {
      case 'E':
        return 'Exhibition';
      case 'R':
        return 'Regular Season';
      case 'T':
        return 'Tournament';
      default:
        return 'Regular Season'; // Default fallback
    }
  }

  // Helper method to get color for game type badges
  PdfColor _getGameTypeColor(String gameType) {
    switch (gameType.toUpperCase()) {
      case 'E':
        return PdfColors.orange; // Exhibition
      case 'R':
        return PdfColors.blue; // Regular Season
      case 'T':
        return PdfColors.purple; // Tournament
      default:
        return PdfColors.blue; // Default fallback
    }
  }

  // Flexible goalie check (handles G, GK, Goalie case-insensitively, or player used as goalie in game events)
  bool _isGoalie(Player player, List<GameEvent> gameEvents) {
    final pos = player.position?.trim().toUpperCase() ?? '';
    if (pos == 'G' || pos == 'GK' || pos == 'GOALIE') {
      return true;
    }
    return gameEvents.any((e) => e.goalieOnIceId == player.id);
  }

  // Calculate game winning goal scorer ID
  String? _getGameWinningGoalPlayerId(List<GameEvent> gameEvents, String teamId) {
    final yourTeamGoals = gameEvents
        .where((e) => e.eventType == 'Shot' && e.isGoal == true && e.team == teamId)
        .toList();
    final opponentGoals = gameEvents
        .where((e) => e.eventType == 'Shot' && e.isGoal == true && e.team == 'opponent')
        .toList();

    if (yourTeamGoals.length <= opponentGoals.length) {
      return null; // Didn't win
    }

    yourTeamGoals.sort((a, b) {
      if (a.period != b.period) return a.period.compareTo(b.period);
      return a.timestamp.compareTo(b.timestamp);
    });

    final gwgIndex = opponentGoals.length;
    if (gwgIndex < yourTeamGoals.length) {
      return yourTeamGoals[gwgIndex].primaryPlayerId;
    }
    return null;
  }

  // Calculate team shooting % and team save %
  Map<String, String> _getTeamShootingAndSavePct(List<GameEvent> gameEvents, String teamId) {
    final teamShots = gameEvents.where((e) => e.eventType == 'Shot' && e.team == teamId).length;
    final teamGoals = gameEvents.where((e) => e.eventType == 'Shot' && e.isGoal == true && e.team == teamId).length;
    final teamShPct = teamShots > 0 ? (teamGoals / teamShots * 100) : 0.0;

    final oppShots = gameEvents.where((e) => e.eventType == 'Shot' && e.team == 'opponent').length;
    final oppGoals = gameEvents.where((e) => e.eventType == 'Shot' && e.isGoal == true && e.team == 'opponent').length;
    final teamSvPct = oppShots > 0 ? ((oppShots - oppGoals) / oppShots * 100) : 0.0;

    return {
      'shPct': '${teamShPct.toStringAsFixed(1)}%',
      'svPct': '${teamSvPct.toStringAsFixed(1)}%',
    };
  }

  Future<File> generateGameStatsPdf({
    required List<Player> players,
    required List<GameEvent> gameEvents,
    required Game game,
    required String teamId,
    bool useLatestData = true,
  }) async {
    // Get the most current data from Google Sheets if requested
    List<GameEvent> currentGameEvents = gameEvents;
    if (useLatestData) {
      try {
        print('PDF Service: Fetching latest data from Google Sheets for game ${game.id}...');
        currentGameEvents = await _centralizedDataService.getCurrentGameEvents(game.id, forceRefresh: true);
        print('PDF Service: Using ${currentGameEvents.length} events from Google Sheets');
      } catch (e) {
        print('PDF Service: Error fetching latest data, using provided data: $e');
        currentGameEvents = gameEvents;
      }
    }
    final pdf = pw.Document();
    
    // Load the team logo dynamically
    pw.MemoryImage? logoImage;
    try {
      final logoPath = await _teamContextService.getCurrentTeamLogoPath();
      final logoBytes = await rootBundle.load(logoPath);
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      print('Failed to load team logo: $e');
      try {
        final logoBytes = await rootBundle.load('assets/logos/waxers_logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e2) {
        print('Failed to load fallback logo: $e2');
      }
    }

    // Flexible goalie detection
    final goalies = players.where((player) => _isGoalie(player, currentGameEvents)).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildCompactHeader(logoImage, game, currentGameEvents, teamId),
              pw.SizedBox(height: 8),

              // Team Statistics & Score Summary Section
              _buildCompactTeamStatsOnly(players, currentGameEvents, teamId, game),
              pw.SizedBox(height: 8),

              // Skater Player Statistics
              pw.Text(
                'Player Statistics',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              _buildCompactPlayerStatsTable(players, currentGameEvents, teamId),
              pw.SizedBox(height: 8),

              // Bottom Section: Goalie Stats & Game Logs
              if (goalies.isNotEmpty) ...[
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 1,
                      child: _buildFullWidthGoalieStats(goalies, currentGameEvents, teamId),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      flex: 1,
                      child: _buildGameLogsBox(currentGameEvents, players, teamId, game),
                    ),
                  ],
                ),
              ] else ...[
                // If no goalies on roster/events, display full-width game logs so no ugly empty box is shown
                _buildGameLogsBox(currentGameEvents, players, teamId, game),
              ],
            ],
          );
        },
      ),
    );

    // Save the PDF to a temporary file with formatted name
    final output = await getTemporaryDirectory();
    final filename = 'Hockey Game Stats - ${game.opponent} - ${_formatDate(game.date)}.pdf';
    final file = File('${output.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Get all players tied for highest points
  List<Map<String, dynamic>> _getTopScorers(List<Player> players, List<GameEvent> gameEvents) {
    final playerStats = <Map<String, dynamic>>[];

    for (final player in players) {
      final goals = gameEvents.where((event) => 
        event.eventType == 'Shot' && 
        event.isGoal == true && 
        event.primaryPlayerId == player.id
      ).length;

      final assists = gameEvents.where((event) => 
        event.eventType == 'Shot' && 
        event.isGoal == true && 
        (event.assistPlayer1Id == player.id || event.assistPlayer2Id == player.id)
      ).length;

      final points = goals + assists;
      if (points > 0) {
        playerStats.add({
          'player': player,
          'points': points,
        });
      }
    }

    if (playerStats.isEmpty) return [];

    final maxPoints = playerStats.map((p) => p['points'] as int).reduce((a, b) => a > b ? a : b);
    return playerStats.where((p) => p['points'] == maxPoints).toList();
  }

  // Get all defensemen tied for highest plus/minus
  List<Map<String, dynamic>> _getTopDefensemen(List<Player> players, List<GameEvent> gameEvents, String teamId) {
    final defensemanStats = <Map<String, dynamic>>[];

    for (final player in players) {
      final pos = player.position?.trim().toUpperCase() ?? '';
      if (pos == 'D' || pos == 'LD' || pos == 'RD' || pos == 'DEFENSE') {
        final plusMinus = StatsService.calculatePlusMinus(player, gameEvents, teamId);
        defensemanStats.add({
          'player': player,
          'plusminus': plusMinus,
        });
      }
    }

    if (defensemanStats.isEmpty) return [];

    final maxPlusMinus = defensemanStats.map((p) => p['plusminus'] as int).reduce((a, b) => a > b ? a : b);
    return defensemanStats.where((p) => p['plusminus'] == maxPlusMinus).toList();
  }

  String _formatPlayerList(List<Map<String, dynamic>> playerStats, String statType) {
    return playerStats.map((stat) {
      final player = stat['player'] as Player;
      final value = stat[statType] as int;
      
      if (statType == 'points') {
        return '#${player.jerseyNumber} (${value}pts)';
      } else if (statType == 'plusminus') {
        return '#${player.jerseyNumber} (${value >= 0 ? '+' : ''}$value)';
      }
      return '#${player.jerseyNumber}';
    }).join(', ');
  }

  // Build compact header with logo and game info
  pw.Widget _buildCompactHeader(pw.MemoryImage? logoImage, Game game, List<GameEvent> gameEvents, String teamId) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Left side - Logo and title
        pw.Row(
          children: [
            if (logoImage != null)
              pw.SizedBox(
                height: 36,
                width: 36,
                child: pw.Image(logoImage),
              ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Game Stats Report',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        
        // Center - Game info with game type
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'vs ${game.opponent}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: _getGameTypeColor(game.gameType),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    _getGameTypeText(game.gameType),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              _formatDate(game.date),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            if (game.location != null) ...[
              pw.SizedBox(height: 1),
              pw.Text(
                game.location!,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ],
        ),
        
        pw.SizedBox(width: 60),
      ],
    );
  }

  // Build compact team statistics section with score summary
  pw.Widget _buildCompactTeamStatsOnly(List<Player> players, List<GameEvent> gameEvents, String teamId, Game game) {
    final teamSOG = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.team == teamId
    ).length;

    final opponentSOG = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.team == 'opponent'
    ).length;

    final yourTeamGoals = gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && event.team == teamId).length;
    final opponentGoals = gameEvents.where((event) => event.eventType == 'Shot' && event.isGoal == true && event.team == 'opponent').length;

    final topScorers = _getTopScorers(players, gameEvents);
    final topDefensemen = _getTopDefensemen(players, gameEvents, teamId);
    final teamEff = _getTeamShootingAndSavePct(gameEvents, teamId);

    // Load attendance to flag scratches/DNP
    List<String> dnpJerseys = [];
    if (gameEvents.isNotEmpty) {
      try {
        final gameId = gameEvents.first.gameId;
        final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
        final attendance = attendanceBox.values
            .where((a) => a.gameId == gameId && a.teamId == teamId)
            .firstOrNull;
        if (attendance != null && attendance.absentPlayerIds.isNotEmpty) {
          final absentSet = attendance.absentPlayerIds.toSet();
          dnpJerseys = players
              .where((p) => absentSet.contains(p.id))
              .map((p) => '#${p.jerseyNumber}')
              .toList();
        }
      } catch (e) {
        print('Error loading attendance for team stats: $e');
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left Box: Score, SOG, Top Performers, Shooting % / Save %
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Final Score: ',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '$yourTeamGoals',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.Text(' - ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      '$opponentGoals',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800,
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      'Shots on Goal: $teamSOG - $opponentSOG',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),

                // Team Shooting & Save %
                pw.Text(
                  'Team Shooting: ${teamEff['shPct']}  |  Team Save %: ${teamEff['svPct']}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 3),

                pw.Text(
                  topScorers.isNotEmpty
                      ? 'Top Scorers: ${_formatPlayerList(topScorers, 'points')}'
                      : 'Top Scorers: None',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  topDefensemen.isNotEmpty
                      ? 'Top Defensemen: ${_formatPlayerList(topDefensemen, 'plusminus')}'
                      : 'Top Defensemen: None',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 4),

                // Special Teams & Discipline Summary Box
                builderSpecialTeamsPdfBox(gameEvents, teamId),
              ],
            ),
          ),
          pw.SizedBox(width: 12),

          // Right Box: Score Summary by Period + Scratches
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildScoreSummaryTable(gameEvents, teamId, game),
                if (dnpJerseys.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Scratches / DNP: ${dnpJerseys.join(', ')}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build Special Teams & Discipline Box
  pw.Widget builderSpecialTeamsPdfBox(List<GameEvent> gameEvents, String teamId) {
    final st = StatsService.getSpecialTeamsStats(gameEvents, teamId);
    final ppStr = '${st.ppGoals}/${st.ppOpportunities} (${st.ppPercentage.toStringAsFixed(1)}%) | S/PP: ${st.ppShotsPerOpp.toStringAsFixed(1)}';
    final pkStr = '${st.pkSuccesses}/${st.pkOpportunities} (${st.pkPercentage.toStringAsFixed(1)}%) | SA/PK: ${st.pkShotsAllowedPerOpp.toStringAsFixed(1)}';
    final stIndex = 'ST Index: ${st.combinedSpecialTeamsIndex.toStringAsFixed(1)}%';
    final netSt = 'Net ST: ${st.netSpecialTeamsGoals > 0 ? "+${st.netSpecialTeamsGoals}" : st.netSpecialTeamsGoals}';
    final netPen = 'Penalties: Taken ${st.penaltiesTaken}, Drawn ${st.penaltiesDrawn} (${st.netPenalties >= 0 ? "+${st.netPenalties}" : st.netPenalties})';

    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Power Play: $ppStr', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('Penalty Kill: $pkStr', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$stIndex | $netSt', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text(netPen, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // Build tabular score summary display
  pw.Widget _buildScoreSummaryTable(List<GameEvent> gameEvents, String teamId, Game game) {
    final Map<int, int> yourTeamGoalsByPeriod = {1: 0, 2: 0, 3: 0, 4: 0};
    final Map<int, int> opponentGoalsByPeriod = {1: 0, 2: 0, 3: 0, 4: 0};
    final Map<int, int> yourTeamShotsByPeriod = {1: 0, 2: 0, 3: 0, 4: 0};
    final Map<int, int> opponentShotsByPeriod = {1: 0, 2: 0, 3: 0, 4: 0};
    
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
    
    final yourTeamTotal = yourTeamGoalsByPeriod.values.fold(0, (a, b) => a + b);
    final opponentTotal = opponentGoalsByPeriod.values.fold(0, (a, b) => a + b);
    final yourTeamShotsTotal = yourTeamShotsByPeriod.values.fold(0, (a, b) => a + b);
    final opponentShotsTotal = opponentShotsByPeriod.values.fold(0, (a, b) => a + b);
    
    final showOT = (yourTeamGoalsByPeriod[4] ?? 0) > 0 || (opponentGoalsByPeriod[4] ?? 0) > 0 ||
                   (yourTeamShotsByPeriod[4] ?? 0) > 0 || (opponentShotsByPeriod[4] ?? 0) > 0;
    
    final yourTeamName = 'Your Team';
    final opponentName = game.opponent;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Score Summary by Period:',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          columnWidths: showOT ? {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(1),
          } : {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: showOT ? [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Team', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('1', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('2', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('3', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('OT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('T', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
              ] : [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Team', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('1', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('2', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('3', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('T', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
              ],
            ),

            // Your team row
            pw.TableRow(
              children: showOT ? [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(yourTeamName, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${yourTeamGoalsByPeriod[1]} [${yourTeamShotsByPeriod[1]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${yourTeamGoalsByPeriod[2]} [${yourTeamShotsByPeriod[2]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${yourTeamGoalsByPeriod[3]} [${yourTeamShotsByPeriod[3]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${yourTeamGoalsByPeriod[4]} [${yourTeamShotsByPeriod[4]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('$yourTeamTotal [$yourTeamShotsTotal]', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
              ] : [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(yourTeamName, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${yourTeamGoalsByPeriod[1]} [${yourTeamShotsByPeriod[1]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${yourTeamGoalsByPeriod[2]} [${yourTeamShotsByPeriod[2]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${yourTeamGoalsByPeriod[3]} [${yourTeamShotsByPeriod[3]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('$yourTeamTotal [$yourTeamShotsTotal]', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
              ],
            ),

            // Opponent team row
            pw.TableRow(
              children: showOT ? [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(opponentName, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${opponentGoalsByPeriod[1]} [${opponentShotsByPeriod[1]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${opponentGoalsByPeriod[2]} [${opponentShotsByPeriod[2]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${opponentGoalsByPeriod[3]} [${opponentShotsByPeriod[3]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${opponentGoalsByPeriod[4]} [${opponentShotsByPeriod[4]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('$opponentTotal [$opponentShotsTotal]', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
              ] : [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(opponentName, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${opponentGoalsByPeriod[1]} [${opponentShotsByPeriod[1]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${opponentGoalsByPeriod[2]} [${opponentShotsByPeriod[2]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('${opponentGoalsByPeriod[3]} [${opponentShotsByPeriod[3]}]', style: const pw.TextStyle(fontSize: 7)))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('$opponentTotal [$opponentShotsTotal]', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Build compact player stats table with dynamic sizing
  pw.Widget _buildCompactPlayerStatsTable(List<Player> players, List<GameEvent> gameEvents, String teamId) {
    if (players.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          'No player data available for this game.',
          style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
        ),
      );
    }

    Set<String> absentPlayerIds = {};
    if (gameEvents.isNotEmpty) {
      try {
        final gameId = gameEvents.first.gameId;
        final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
        final attendance = attendanceBox.values
            .where((a) => a.gameId == gameId && a.teamId == teamId)
            .firstOrNull;
        if (attendance != null) {
          absentPlayerIds = attendance.absentPlayerIds.toSet();
        }
      } catch (e) {
        print('Error loading attendance for PDF: $e');
      }
    }

    final gwgPlayerId = _getGameWinningGoalPlayerId(gameEvents, teamId);

    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));

    double fontSize;
    double padding;
    if (sortedPlayers.length > 20) {
      fontSize = 7;
      padding = 2;
    } else if (sortedPlayers.length > 15) {
      fontSize = 8;
      padding = 2.5;
    } else {
      fontSize = 8.5;
      padding = 3;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.7), // #
            1: pw.FlexColumnWidth(1.2), // POS
            2: pw.FlexColumnWidth(0.7), // G
            3: pw.FlexColumnWidth(0.7), // A
            4: pw.FlexColumnWidth(0.8), // PTS
            5: pw.FlexColumnWidth(0.8), // +/-
            6: pw.FlexColumnWidth(0.8), // PIM
            7: pw.FlexColumnWidth(1.2), // SF/SA
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: pw.EdgeInsets.all(padding),
                  child: pw.Center(child: pw.Text('#', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(padding),
                  child: pw.Center(child: pw.Text('POS', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(padding),
                  child: pw.Center(child: pw.Text('G', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(padding),
                  child: pw.Center(child: pw.Text('A', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(padding),
                  child: pw.Center(child: pw.Text('PTS', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(padding),
                  child: pw.Center(child: pw.Text('+/-', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(padding),
                  child: pw.Center(child: pw.Text('PIM', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                ),
                pw.Padding(
                  padding: pw.EdgeInsets.all(padding),
                  child: pw.Center(child: pw.Text('SF/SA', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                ),
              ],
            ),

            // Player Rows
            ...sortedPlayers.map((player) {
              final isAbsent = absentPlayerIds.contains(player.id);
              final goals = StatsService.calculateGoals(player, gameEvents);
              final assists = StatsService.calculateAssists(player, gameEvents);
              final points = goals + assists;
              final plusMinus = StatsService.calculatePlusMinus(player, gameEvents, teamId);
              final pim = StatsService.calculatePenaltyMinutes(player, gameEvents);

              final onIceStats = StatsService.getOnIceShotStats(player, gameEvents, teamId);
              final sfSaStr = '${onIceStats.shotsForOnIce}/${onIceStats.shotsAgainstOnIce}';

              final isGwg = gwgPlayerId != null && gwgPlayerId == player.id;
              final goalsStr = isGwg ? '$goals*' : goals.toString();

              final cellTextColor = isAbsent ? PdfColors.grey600 : PdfColors.black;
              final cellFontStyle = isAbsent ? pw.FontStyle.italic : pw.FontStyle.normal;

              return pw.TableRow(
                decoration: isAbsent ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(padding),
                    child: pw.Center(child: pw.Text(player.jerseyNumber.toString(), style: pw.TextStyle(fontSize: fontSize, color: cellTextColor, fontStyle: cellFontStyle))),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(padding),
                    child: pw.Center(
                      child: pw.Text(
                        isAbsent ? '${player.position ?? 'N/A'} (DNP)' : (player.position ?? 'N/A'),
                        style: pw.TextStyle(fontSize: fontSize, color: cellTextColor, fontStyle: cellFontStyle),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(padding),
                    child: pw.Center(child: pw.Text(goalsStr, style: pw.TextStyle(fontSize: fontSize, color: cellTextColor, fontStyle: cellFontStyle, fontWeight: isGwg ? pw.FontWeight.bold : pw.FontWeight.normal))),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(padding),
                    child: pw.Center(child: pw.Text(assists.toString(), style: pw.TextStyle(fontSize: fontSize, color: cellTextColor, fontStyle: cellFontStyle))),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(padding),
                    child: pw.Center(child: pw.Text(points.toString(), style: pw.TextStyle(fontSize: fontSize, color: cellTextColor, fontStyle: cellFontStyle, fontWeight: pw.FontWeight.bold))),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(padding),
                    child: pw.Center(child: pw.Text(plusMinus.toString(), style: pw.TextStyle(fontSize: fontSize, color: cellTextColor, fontStyle: cellFontStyle))),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(padding),
                    child: pw.Center(child: pw.Text(pim.toString(), style: pw.TextStyle(fontSize: fontSize, color: cellTextColor, fontStyle: cellFontStyle))),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(padding),
                    child: pw.Center(child: pw.Text(sfSaStr, style: pw.TextStyle(fontSize: fontSize, color: cellTextColor, fontStyle: cellFontStyle))),
                  ),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          '* GWG = Game Winning Goal Scorer  |  SF/SA = On-Ice Shots For / Shots Against  |  DNP = Did Not Play',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
      ],
    );
  }

  // Build full-width goalie statistics section
  pw.Widget _buildFullWidthGoalieStats(List<Player> goalies, List<GameEvent> gameEvents, String teamId) {
    if (goalies.isEmpty) {
      return pw.SizedBox();
    }

    final isOnlyGoalie = goalies.length == 1;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GOALIE STATISTICS',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.8), // #
              1: pw.FlexColumnWidth(0.9), // SA
              2: pw.FlexColumnWidth(0.9), // GA
              3: pw.FlexColumnWidth(0.9), // SV
              4: pw.FlexColumnWidth(1.2), // SV%
              5: pw.FlexColumnWidth(1.2), // EV SV%
              6: pw.FlexColumnWidth(1.2), // PK SV%
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('#', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('SA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('GA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('SV', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('SV%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('EV SV%', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text('PK SV%', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)))),
                ],
              ),

              // Goalie data rows
              ...goalies.map((goalie) {
                final goalieStats = StatsService.getGoalieStats(
                  goalie,
                  gameEvents,
                  teamId,
                  teamGoalies: goalies,
                );

                // Calculate Situational SV% (Even Strength vs PK)
                final evShots = gameEvents.where((e) =>
                  e.eventType == 'Shot' &&
                  e.team != teamId &&
                  e.goalSituation == GoalSituation.evenStrength &&
                  (e.goalieOnIceId == goalie.id || (isOnlyGoalie && (e.goalieOnIceId == null || e.goalieOnIceId!.isEmpty)))
                ).length;

                final evGoals = gameEvents.where((e) =>
                  e.eventType == 'Shot' &&
                  e.isGoal == true &&
                  e.team != teamId &&
                  e.goalSituation == GoalSituation.evenStrength &&
                  (e.goalieOnIceId == goalie.id || (isOnlyGoalie && (e.goalieOnIceId == null || e.goalieOnIceId!.isEmpty)))
                ).length;

                final evSvPctStr = evShots > 0 ? '${((evShots - evGoals) / evShots * 100).toStringAsFixed(1)}%' : '0.0%';

                final pkShots = gameEvents.where((e) =>
                  e.eventType == 'Shot' &&
                  e.team != teamId &&
                  e.goalSituation == GoalSituation.powerPlay &&
                  (e.goalieOnIceId == goalie.id || (isOnlyGoalie && (e.goalieOnIceId == null || e.goalieOnIceId!.isEmpty)))
                ).length;

                final pkGoals = gameEvents.where((e) =>
                  e.eventType == 'Shot' &&
                  e.isGoal == true &&
                  e.team != teamId &&
                  e.goalSituation == GoalSituation.powerPlay &&
                  (e.goalieOnIceId == goalie.id || (isOnlyGoalie && (e.goalieOnIceId == null || e.goalieOnIceId!.isEmpty)))
                ).length;

                final pkSvPctStr = pkShots > 0 ? '${((pkShots - pkGoals) / pkShots * 100).toStringAsFixed(1)}%' : '0.0%';

                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text(goalie.jerseyNumber.toString(), style: const pw.TextStyle(fontSize: 8)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text(goalieStats.shotsAgainst.toString(), style: const pw.TextStyle(fontSize: 8)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text(goalieStats.goalsAgainst.toString(), style: const pw.TextStyle(fontSize: 8)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text(goalieStats.saves.toString(), style: const pw.TextStyle(fontSize: 8)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text(
                      goalieStats.savePercentage > 0
                          ? '${(goalieStats.savePercentage * 100).toStringAsFixed(1)}%'
                          : '0.0%',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text(evSvPctStr, style: const pw.TextStyle(fontSize: 7)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Center(child: pw.Text(pkSvPctStr, style: const pw.TextStyle(fontSize: 7)))),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'SA = Shots Against | GA = Goals Against | SV = Saves | SV% = Save % | EV SV% = Even Strength SV% | PK SV% = Penalty Kill SV%',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // Build Chronological Game Event Logs (Scoring Log + Penalty Log)
  pw.Widget _buildGameLogsBox(List<GameEvent> gameEvents, List<Player> players, String teamId, Game game) {
    final playerJerseyMap = {for (var p in players) p.id: p.jerseyNumber};

    // Goals Log
    final goals = gameEvents.where((e) => e.eventType == 'Shot' && e.isGoal == true).toList();
    goals.sort((a, b) {
      if (a.period != b.period) return a.period.compareTo(b.period);
      return a.timestamp.compareTo(b.timestamp);
    });

    int yourTeamScore = 0;
    int opponentScore = 0;
    final goalRows = <pw.Widget>[];

    for (final goal in goals) {
      final isYourTeam = goal.team == teamId;
      if (isYourTeam) {
        yourTeamScore++;
      } else {
        opponentScore++;
      }

      final periodStr = goal.period == 4 ? 'OT' : 'P${goal.period}';
      final timeStr = (goal.gameClockTime != null && goal.gameClockTime!.isNotEmpty) ? goal.gameClockTime! : '';
      final sitStr = goal.goalSituation == GoalSituation.powerPlay ? ' (PP)' : (goal.goalSituation == GoalSituation.shortHanded ? ' (SH)' : '');

      String scorerStr = '';
      if (isYourTeam) {
        final j = playerJerseyMap[goal.primaryPlayerId];
        scorerStr = j != null ? '#$j' : 'Your Team';
        final assists = <String>[];
        if (goal.assistPlayer1Id != null && playerJerseyMap.containsKey(goal.assistPlayer1Id)) {
          assists.add('#${playerJerseyMap[goal.assistPlayer1Id]}');
        }
        if (goal.assistPlayer2Id != null && playerJerseyMap.containsKey(goal.assistPlayer2Id)) {
          assists.add('#${playerJerseyMap[goal.assistPlayer2Id]}');
        }
        if (assists.isNotEmpty) {
          scorerStr += ' (A: ${assists.join(', ')})';
        }
      } else {
        scorerStr = game.opponent;
      }

      goalRows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '$periodStr ${timeStr.isNotEmpty ? timeStr + ' ' : ''}| $scorerStr$sitStr',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: isYourTeam ? PdfColors.blue800 : PdfColors.red800,
                  fontWeight: isYourTeam ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
              pw.Text('$yourTeamScore-$opponentScore', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // Penalty Log
    final penalties = gameEvents.where((e) => e.eventType == 'Penalty').toList();
    penalties.sort((a, b) {
      if (a.period != b.period) return a.period.compareTo(b.period);
      return a.timestamp.compareTo(b.timestamp);
    });

    final penaltyRows = <pw.Widget>[];
    for (final penalty in penalties.take(6)) {
      final isYourTeam = penalty.team == teamId;
      final periodStr = penalty.period == 4 ? 'OT' : 'P${penalty.period}';
      final timeStr = (penalty.gameClockTime != null && penalty.gameClockTime!.isNotEmpty) ? penalty.gameClockTime! : '';

      String pStr = '';
      if (isYourTeam) {
        final j = playerJerseyMap[penalty.primaryPlayerId];
        pStr = j != null ? '#$j' : 'Your Team';
      } else {
        pStr = game.opponent;
      }

      final pType = penalty.penaltyType ?? 'Penalty';
      final pDur = penalty.penaltyDuration != null ? '${penalty.penaltyDuration}m' : '2m';

      penaltyRows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
          child: pw.Text(
            '$periodStr ${timeStr.isNotEmpty ? timeStr + ' ' : ''}| $pStr - $pType ($pDur)',
            style: pw.TextStyle(
              fontSize: 7.5,
              color: isYourTeam ? PdfColors.blue800 : PdfColors.black,
            ),
          ),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SCORING SUMMARY LOG', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          if (goalRows.isEmpty)
            pw.Text('No goals logged.', style: const pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic))
          else
            ...goalRows,

          pw.SizedBox(height: 4),
          pw.Text('PENALTY LOG', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          if (penaltyRows.isEmpty)
            pw.Text('No penalties logged.', style: const pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic))
          else
            ...penaltyRows,
        ],
      ),
    );
  }
}
