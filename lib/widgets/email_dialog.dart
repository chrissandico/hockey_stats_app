import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/email_service.dart';
import 'package:hockey_stats_app/services/pdf_service.dart';
import 'package:printing/printing.dart';

class EmailDialog extends StatefulWidget {
  final List<Player> players;
  final List<GameEvent> gameEvents;
  final Game game;
  final String teamId;

  const EmailDialog({
    super.key,
    required this.players,
    required this.gameEvents,
    required this.game,
    required this.teamId,
  });

  @override
  State<EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<EmailDialog> {
  final _emailService = EmailService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _useDefaultEmails = true;
  List<String> _defaultEmails = [];
  @override
  void initState() {
    super.initState();
    _loadDefaultEmails();
  }

  Future<void> _loadDefaultEmails() async {
    final emails = await _emailService.getDefaultEmailAddresses();
    setState(() {
      _defaultEmails = emails;
      if (emails.isNotEmpty) {
        _emailController.text = emails.join(', ');
      }
    });
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    final emails = _emailController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one email address')),
      );
      return;
    }

    try {
      // If using custom emails and save as default is checked, save them
      if (!_useDefaultEmails) {
        await _emailService.saveDefaultEmailAddresses(emails);
      }

      // Send the email
      await _emailService.sendStatsEmail(
        recipients: emails,
        players: widget.players,
        gameEvents: widget.gameEvents,
        game: widget.game,
        teamId: widget.teamId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stats sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        // Close the email dialog first
        Navigator.of(context).pop();
        
        // Show error in a dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Sending Stats'),
            content: Text('Failed to send stats: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Send Stats via Email',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_defaultEmails.isNotEmpty) ...[
                CheckboxListTile(
                  title: const Text('Use default email addresses'),
                  value: _useDefaultEmails,
                  onChanged: (value) {
                    setState(() {
                      _useDefaultEmails = value ?? false;
                      if (_useDefaultEmails) {
                        _emailController.text = _defaultEmails.join(', ');
                      } else {
                        _emailController.clear();
                      }
                    });
                  },
                ),
              ],
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Addresses',
                  helperText: 'Separate multiple addresses with commas',
                ),
                enabled: !_useDefaultEmails || _defaultEmails.isEmpty,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter at least one email address';
                  }
                  final emails = value.split(',').map((e) => e.trim()).toList();
                  for (final email in emails) {
                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Please enter valid email addresses';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Preview:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 400,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: PdfPreview(
                  build: (format) => PdfService().generateGameStatsPdf(
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _handleSend,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
