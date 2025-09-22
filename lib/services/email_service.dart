import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/pdf_service.dart';
import 'package:hockey_stats_app/services/team_context_service.dart';
import 'package:hockey_stats_app/services/stats_service.dart';

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
    
    // Get the current team name dynamically
    final teamContextService = TeamContextService();
    final teamName = await teamContextService.getCurrentTeamName();
    
    final Email email = Email(
      recipients: recipients,
      subject: 'Hockey Game Stats - ${game.opponent} - $formattedDate',
      body: 'Please see attached PDF for complete game statistics.\n\n$teamName vs ${game.opponent}\n$formattedDate',
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

}
