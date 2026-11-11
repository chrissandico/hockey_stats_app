import 'dart:async';

import 'package:flutter/material.dart';

/// What the keeper decided on the verify-before-logging card.
enum VoiceVerifyDecision { confirm, edit, discard }

/// Shows a parsed voice command for verification BEFORE anything is logged
/// (Prof's standing rule for voice control: the keeper always sees what was
/// captured first). The card shows the event in plain terms, what was
/// actually heard, and a countdown — an unconfirmed capture expires and is
/// discarded, never auto-logged.
///
/// Returns the keeper's [VoiceVerifyDecision]; dismissing the sheet (tap
/// outside, back button, or expiry) counts as discard.
Future<VoiceVerifyDecision> showVoiceVerifySheet(
  BuildContext context, {
  required String description,
  String? heardText,
  bool showEdit = false,
  Duration expiry = const Duration(seconds: 30),
}) async {
  final decision = await showModalBottomSheet<VoiceVerifyDecision>(
    context: context,
    isDismissible: true,
    enableDrag: false,
    builder: (context) => _VoiceVerifySheet(
      description: description,
      heardText: heardText,
      showEdit: showEdit,
      expiry: expiry,
    ),
  );
  return decision ?? VoiceVerifyDecision.discard;
}

class _VoiceVerifySheet extends StatefulWidget {
  final String description;
  final String? heardText;
  final bool showEdit;
  final Duration expiry;

  const _VoiceVerifySheet({
    required this.description,
    required this.heardText,
    required this.showEdit,
    required this.expiry,
  });

  @override
  State<_VoiceVerifySheet> createState() => _VoiceVerifySheetState();
}

class _VoiceVerifySheetState extends State<_VoiceVerifySheet> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.expiry.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        timer.cancel();
        Navigator.of(context).pop(VoiceVerifyDecision.discard);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _decide(VoiceVerifyDecision decision) {
    _timer?.cancel();
    Navigator.of(context).pop(decision);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Did I hear this right?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  'Discards in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.description,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (widget.heardText != null) ...[
              const SizedBox(height: 6),
              Text(
                'Heard: "${widget.heardText}"',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _decide(VoiceVerifyDecision.confirm),
              icon: const Icon(Icons.check),
              label: const Text('Log it'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.showEdit)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _decide(VoiceVerifyDecision.edit),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (widget.showEdit) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decide(VoiceVerifyDecision.discard),
                    icon: const Icon(Icons.close),
                    label: const Text('Discard'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows why a voice capture was NOT parsed (nothing was logged), with the
/// option to try again immediately. Returns true when the keeper chose
/// "Try again".
Future<bool> showVoiceRejectionSheet(
  BuildContext context, {
  required String reason,
  String? heardText,
}) async {
  final retry = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    enableDrag: false,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.hearing_disabled, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Nothing logged',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(reason, style: const TextStyle(fontSize: 16)),
            if (heardText != null) ...[
              const SizedBox(height: 6),
              Text(
                'Heard: "$heardText"',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.mic),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    ),
  );
  return retry ?? false;
}
