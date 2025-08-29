import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/pdf_service.dart';

class EmailService {
  static const String _emailSettingsBoxName = 'emailSettings';
  
  // Get default email addresses from Hive
  Future<List<String>> getDefaultEmailAddresses() async {
    final box = await Hive.openBox<EmailSettings>(_emailSettingsBoxName);
    final settings = box.get('default');
    return settings?.defaultEmailAddresses ?? [];
  }

  // Save default email addresses to Hive
  Future<void> saveDefaultEmailAddresses(List<String> emails) async {
    final box = await Hive.openBox<EmailSettings>(_emailSettingsBoxName);
    await box.put('default', EmailSettings(defaultEmailAddresses: emails));
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Send email with game stats and PDF attachment
  Future<void> sendStatsEmail({
    required List<String> recipients,
    required List<Player> players,
    required List<GameEvent> gameEvents,
    required Game game,
    required String teamId,
  }) async {
    final pdfService = PdfService();
    final pdfFile = await pdfService.generateGameStatsPdf(
      players: players,
      gameEvents: gameEvents,
      game: game,
      teamId: teamId,
    );

    final formattedDate = _formatDate(game.date);
    
    // Calculate the score for the email body
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
    
    final Email email = Email(
      recipients: recipients,
      subject: 'Hockey Game Stats - ${game.opponent} - $formattedDate',
      body: 'Game stats for Waxers vs ${game.opponent} on $formattedDate.\n\nFinal Score: $yourTeamScore - $opponentScore\n\nDetailed stats attached as PDF.',
      attachmentPaths: [pdfFile.path],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (e) {
      if (e.toString().contains('No email clients found')) {
        throw Exception('No email app found on this device. Please install an email app to use this feature.');
      } else {
        throw Exception('Failed to send email: $e');
      }
    }
  }

  // Helper method to calculate plus/minus
  int _calculatePlusMinus(Player player, List<GameEvent> gameEvents) {
    // Skip plus/minus calculation for goalies
    if (player.position == 'G') {
      return 0;
    }
    
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
