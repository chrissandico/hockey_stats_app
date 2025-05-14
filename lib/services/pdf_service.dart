import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:hockey_stats_app/models/data_models.dart';

class PdfService {
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<File> generateGameStatsPdf({
    required List<Player> players,
    required List<GameEvent> gameEvents,
    required Game game,
  }) async {
    final pdf = pw.Document();
    
    // Load the team logo
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/logos/waxers_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      print('Failed to load logo: $e');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with logo and game details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (logoImage != null)
                    pw.SizedBox(
                      height: 60,
                      width: 60,
                      child: pw.Image(logoImage),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Game Stats', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('vs ${game.opponent}'),
                      pw.Text('Date: ${_formatDate(game.date)}'),
                      if (game.location != null)
                        pw.Text('Location: ${game.location}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Stats table
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1), // #
                  1: const pw.FlexColumnWidth(1), // POS
                  2: const pw.FlexColumnWidth(1), // G
                  3: const pw.FlexColumnWidth(1), // A
                  4: const pw.FlexColumnWidth(1), // +/-
                  5: const pw.FlexColumnWidth(1), // PIM
                  6: const pw.FlexColumnWidth(1), // SOG
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
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('SOG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  // Player rows
                  ...players.map((player) {
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

                    final plusMinus = _calculatePlusMinus(player, gameEvents);

                    final pim = gameEvents
                      .where((event) => event.eventType == 'Penalty' && event.primaryPlayerId == player.id)
                      .map((event) => event.penaltyDuration ?? 0)
                      .fold(0, (a, b) => a + b);

                    final shots = gameEvents.where((event) => 
                      event.eventType == 'Shot' && 
                      event.primaryPlayerId == player.id
                    ).length;

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(player.jerseyNumber.toString())),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(player.position ?? 'N/A')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(goals.toString())),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(assists.toString())),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(plusMinus.toString())),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(pim.toString())),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(shots.toString())),
                      ],
                    );
                  }).toList(),
                ],
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

  // Helper method to calculate plus/minus
  int _calculatePlusMinus(Player player, List<GameEvent> gameEvents) {
    int plusMinus = 0;

    for (var event in gameEvents) {
      if (event.eventType == 'Shot' && event.isGoal == true) {
        bool playerWasOnIce = false;

        if (event.team == 'your_team') {
          if (event.yourTeamPlayersOnIce != null && event.yourTeamPlayersOnIce!.isNotEmpty) {
            playerWasOnIce = event.yourTeamPlayersOnIce!.contains(player.id);
          } else {
            playerWasOnIce = event.primaryPlayerId == player.id || 
                            event.assistPlayer1Id == player.id || 
                            event.assistPlayer2Id == player.id;
          }
          if (playerWasOnIce) {
            plusMinus++;
          }
        } else if (event.team == 'opponent') {
          if (event.yourTeamPlayersOnIce != null && event.yourTeamPlayersOnIce!.isNotEmpty) {
            playerWasOnIce = event.yourTeamPlayersOnIce!.contains(player.id);
            if (playerWasOnIce) {
              plusMinus--;
            }
          }
        }
      }
    }

    return plusMinus;
  }
}
