import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/pdf_service.dart';
import 'package:hockey_stats_app/widgets/email_dialog.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ShareDialog extends StatefulWidget {
  final List<Player> players;
  final List<GameEvent> gameEvents;
  final Game game;
  final String teamId;

  const ShareDialog({
    super.key,
    required this.players,
    required this.gameEvents,
    required this.game,
    required this.teamId,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final _pdfService = PdfService();
  bool _isGeneratingPdf = false;

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<File> _generatePdf() async {
    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final pdfFile = await _pdfService.generateGameStatsPdf(
        players: widget.players,
        gameEvents: widget.gameEvents,
        game: widget.game,
        teamId: widget.teamId,
      );
      return pdfFile;
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<void> _shareViaEmail() async {
    Navigator.of(context).pop(); // Close share dialog
    
    // Open the existing email dialog
    await showDialog(
      context: context,
      builder: (context) => EmailDialog(
        players: widget.players,
        gameEvents: widget.gameEvents,
        game: widget.game,
        teamId: widget.teamId,
      ),
    );
  }

  Future<void> _shareToApps() async {
    try {
      final pdfFile = await _generatePdf();
      final formattedDate = _formatDate(widget.game.date);
      
      // Calculate the score for the share text
      int yourTeamScore = widget.gameEvents.where((event) => 
        event.eventType == 'Shot' && 
        event.isGoal == true && 
        event.team == widget.teamId
      ).length;

      int opponentScore = widget.gameEvents.where((event) => 
        event.eventType == 'Shot' && 
        event.isGoal == true && 
        event.team == 'opponent'
      ).length;

      final shareText = 'Hockey Game Stats - Waxers vs ${widget.game.opponent} on $formattedDate\n\nFinal Score: $yourTeamScore - $opponentScore\n\nDetailed stats attached.';

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: shareText,
        subject: 'Hockey Game Stats - ${widget.game.opponent} - $formattedDate',
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stats shared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing stats: $e')),
        );
      }
    }
  }

  Future<void> _savePdfToDevice() async {
    try {
      final pdfFile = await _generatePdf();
      
      // Get the downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir != null) {
        final formattedDate = _formatDate(widget.game.date);
        final fileName = 'Hockey_Game_Stats_${widget.game.opponent}_$formattedDate.pdf';
        final savedFile = File('${downloadsDir.path}/$fileName');
        
        await pdfFile.copy(savedFile.path);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to ${savedFile.path}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDate(widget.game.date);
    
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.share, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Share Game Stats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'vs ${widget.game.opponent} - $formattedDate',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // PDF Preview
            const Text(
              'Preview:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: PdfPreview(
                build: (format) => _pdfService.generateGameStatsPdf(
                  players: widget.players,
                  gameEvents: widget.gameEvents,
                  game: widget.game,
                  teamId: widget.teamId,
                ).then((file) => file.readAsBytes()),
                maxPageWidth: 700,
                canChangePageFormat: false,
                canChangeOrientation: false,
                allowPrinting: false,
                allowSharing: false,
              ),
            ),
            const SizedBox(height: 20),

            // Sharing Options
            const Text(
              'Choose sharing method:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Email Option
            _buildShareOption(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'Send via email with custom recipients',
              onTap: _shareViaEmail,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),

            // Share to Apps Option
            _buildShareOption(
              icon: Icons.share,
              title: 'Share to Apps',
              subtitle: 'WhatsApp, Messages, and other apps',
              onTap: _isGeneratingPdf ? null : _shareToApps,
              color: Colors.green,
            ),
            const SizedBox(height: 8),

            // Save to Device Option
            _buildShareOption(
              icon: Icons.download,
              title: 'Save to Device',
              subtitle: 'Save PDF to downloads folder',
              onTap: _isGeneratingPdf ? null : _savePdfToDevice,
              color: Colors.orange,
            ),

            const SizedBox(height: 20),

            // Loading indicator
            if (_isGeneratingPdf)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Generating PDF...'),
                ],
              ),

            // Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
        trailing: onTap == null 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }
}
