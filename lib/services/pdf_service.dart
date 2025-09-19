import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/team_context_service.dart';
import 'package:hockey_stats_app/services/stats_service.dart';

class PdfService {
  final TeamContextService _teamContextService = TeamContextService();

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<File> generateGameStatsPdf({
    required List<Player> players,
    required List<GameEvent> gameEvents,
    required Game game,
    required String teamId,
  }) async {
    final pdf = pw.Document();
    
    // Load the team logo dynamically
    pw.MemoryImage? logoImage;
    try {
      final logoPath = await _teamContextService.getCurrentTeamLogoPath();
      final logoBytes = await rootBundle.load(logoPath);
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      print('Failed to load team logo: $e');
      // Try fallback to generic logo
      try {
        final logoBytes = await rootBundle.load('assets/logos/waxers_logo.png'); // Use PNG instead of corrupted SVG
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e2) {
        print('Failed to load fallback logo: $e2');
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Compact header
              _buildCompactHeader(logoImage, game, gameEvents, teamId),
              pw.SizedBox(height: 12),
              
              // Main content in side-by-side layout
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left column - Team stats (30% width)
                    pw.Expanded(
                      flex: 3,
                      child: _buildCompactTeamStats(players, gameEvents, teamId),
                    ),
                    pw.SizedBox(width: 15),
                    
                    // Right column - Player stats table (70% width)
                    pw.Expanded(
                      flex: 7,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Individual Player Stats',
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Expanded(
                            child: _buildCompactPlayerStatsTable(players, gameEvents, teamId),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

  // Build a score summary widget for the PDF
  pw.Widget _buildScoreSummary(List<GameEvent> gameEvents, String teamId) {
    // Calculate the score
    int yourTeamScore = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.team == teamId
    ).length;

    int opponentScore = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.team == 'opponent'
    ).length;

    // Return a row with the score
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          'Score: ',
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.Text(
          '$yourTeamScore',
          style: pw.TextStyle(
            fontSize: 16, 
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue,
          ),
        ),
        pw.Text(
          ' - ',
          style: pw.TextStyle(
            fontSize: 16, 
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          '$opponentScore',
          style: pw.TextStyle(
            fontSize: 16, 
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red,
          ),
        ),
      ],
    );
  }

  // Build team statistics section
  pw.Widget _buildTeamStats(List<Player> players, List<GameEvent> gameEvents, String teamId) {
    // Calculate team shots on goal
    final teamSOG = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.team == teamId
    ).length;

    final opponentSOG = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.team == 'opponent'
    ).length;

    // Get top scorers and defensemen
    final topScorers = _getTopScorers(players, gameEvents);
    final topDefensemen = _getTopDefensemen(players, gameEvents, teamId);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TEAM STATISTICS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Shots on Goal: $teamSOG - $opponentSOG',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            topScorers.isNotEmpty 
                ? 'Top Scorer${topScorers.length > 1 ? 's' : ''}: ${_formatPlayerList(topScorers, 'points')}'
                : 'Top Scorer: None',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            topDefensemen.isNotEmpty 
                ? 'Top Defensem${topDefensemen.length > 1 ? 'en' : 'an'}: ${_formatPlayerList(topDefensemen, 'plusminus')}'
                : 'Top Defenseman: None',
            style: const pw.TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
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

    // Find the highest points total
    final maxPoints = playerStats.map((p) => p['points'] as int).reduce((a, b) => a > b ? a : b);
    
    // Return all players with the highest points
    return playerStats.where((p) => p['points'] == maxPoints).toList();
  }

  // Get all defensemen tied for highest plus/minus
  List<Map<String, dynamic>> _getTopDefensemen(List<Player> players, List<GameEvent> gameEvents, String teamId) {
    final defensemanStats = <Map<String, dynamic>>[];

    for (final player in players) {
      // Only include defensemen
      if (player.position == 'D' || player.position == 'LD' || player.position == 'RD') {
        final plusMinus = StatsService.calculatePlusMinus(player, gameEvents, teamId);
        defensemanStats.add({
          'player': player,
          'plusminus': plusMinus,
        });
      }
    }

    if (defensemanStats.isEmpty) return [];

    // Find the highest plus/minus
    final maxPlusMinus = defensemanStats.map((p) => p['plusminus'] as int).reduce((a, b) => a > b ? a : b);
    
    // Return all defensemen with the highest plus/minus
    return defensemanStats.where((p) => p['plusminus'] == maxPlusMinus).toList();
  }

  // Build the player stats table
  pw.Widget _buildPlayerStatsTable(List<Player> players, List<GameEvent> gameEvents, String teamId) {
    print('PDF: Building player stats table with ${players.length} players');
    
    if (players.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          'No player data available for this game.',
          style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
        ),
      );
    }

    // Sort players by jersey number
    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(1), // #
        1: const pw.FlexColumnWidth(1), // POS
        2: const pw.FlexColumnWidth(1), // G
        3: const pw.FlexColumnWidth(1), // A
        4: const pw.FlexColumnWidth(1), // +/-
        5: const pw.FlexColumnWidth(1), // PIM
      },
      children: [
        // Table header
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('POS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('G', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('A', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('+/-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('PIM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ],
        ),
        // Player rows
        ...sortedPlayers.map((player) {
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

          final plusMinus = StatsService.calculatePlusMinus(player, gameEvents, teamId);

          final pim = gameEvents
            .where((event) => event.eventType == 'Penalty' && event.primaryPlayerId == player.id)
            .map((event) => event.penaltyDuration ?? 0)
            .fold(0, (a, b) => a + b);

          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(player.jerseyNumber.toString())),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(player.position ?? 'N/A')),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(goals.toString())),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(assists.toString())),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(plusMinus.toString())),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(pim.toString())),
            ],
          );
        }),
      ],
    );
  }

  // Format a list of players for display
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


  // Build compact header with logo and game info in horizontal layout
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
                height: 40,
                width: 40,
                child: pw.Image(logoImage),
              ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Game Stats',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        
        // Center - Game info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'vs ${game.opponent}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _formatDate(game.date),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            if (game.location != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                game.location!,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ],
        ),
        
        // Right side - Score
        _buildCompactScore(gameEvents, teamId),
      ],
    );
  }

  // Build compact score display
  pw.Widget _buildCompactScore(List<GameEvent> gameEvents, String teamId) {
    int yourTeamScore = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.team == teamId
    ).length;

    int opponentScore = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.isGoal == true && 
      event.team == 'opponent'
    ).length;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$yourTeamScore',
            style: pw.TextStyle(
              fontSize: 16, 
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
          ),
          pw.Text(
            ' - ',
            style: pw.TextStyle(
              fontSize: 16, 
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '$opponentScore',
            style: pw.TextStyle(
              fontSize: 16, 
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red,
            ),
          ),
        ],
      ),
    );
  }

  // Build compact team statistics section
  pw.Widget _buildCompactTeamStats(List<Player> players, List<GameEvent> gameEvents, String teamId) {
    final teamSOG = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.team == teamId
    ).length;

    final opponentSOG = gameEvents.where((event) => 
      event.eventType == 'Shot' && 
      event.team == 'opponent'
    ).length;

    final topScorers = _getTopScorers(players, gameEvents);
    final topDefensemen = _getTopDefensemen(players, gameEvents, teamId);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TEAM STATISTICS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Shots on Goal:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '$teamSOG - $opponentSOG',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Top Scorers:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            topScorers.isNotEmpty 
                ? _formatPlayerList(topScorers, 'points')
                : 'None',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Top Defensemen:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            topDefensemen.isNotEmpty 
                ? _formatPlayerList(topDefensemen, 'plusminus')
                : 'None',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
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
          style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
        ),
      );
    }

    // Sort players by jersey number
    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));

    // Dynamic font size based on number of players
    double fontSize;
    double padding;
    if (sortedPlayers.length > 20) {
      fontSize = 8;
      padding = 3;
    } else if (sortedPlayers.length > 15) {
      fontSize = 9;
      padding = 4;
    } else {
      fontSize = 10;
      padding = 5;
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1), // #
        1: const pw.FlexColumnWidth(1.2), // POS
        2: const pw.FlexColumnWidth(0.8), // G
        3: const pw.FlexColumnWidth(0.8), // A
        4: const pw.FlexColumnWidth(1), // +/-
        5: const pw.FlexColumnWidth(1), // PIM
      },
      children: [
        // Table header
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(padding),
              child: pw.Text('#', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(padding),
              child: pw.Text('POS', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(padding),
              child: pw.Text('G', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(padding),
              child: pw.Text('A', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(padding),
              child: pw.Text('+/-', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(padding),
              child: pw.Text('PIM', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        // Player rows
        ...sortedPlayers.map((player) {
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

          final plusMinus = StatsService.calculatePlusMinus(player, gameEvents, teamId);

          final pim = gameEvents
            .where((event) => event.eventType == 'Penalty' && event.primaryPlayerId == player.id)
            .map((event) => event.penaltyDuration ?? 0)
            .fold(0, (a, b) => a + b);

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(padding),
                child: pw.Text(player.jerseyNumber.toString(), style: pw.TextStyle(fontSize: fontSize)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(padding),
                child: pw.Text(player.position ?? 'N/A', style: pw.TextStyle(fontSize: fontSize)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(padding),
                child: pw.Text(goals.toString(), style: pw.TextStyle(fontSize: fontSize)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(padding),
                child: pw.Text(assists.toString(), style: pw.TextStyle(fontSize: fontSize)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(padding),
                child: pw.Text(plusMinus.toString(), style: pw.TextStyle(fontSize: fontSize)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(padding),
                child: pw.Text(pim.toString(), style: pw.TextStyle(fontSize: fontSize)),
              ),
            ],
          );
        }),
      ],
    );
  }
}
