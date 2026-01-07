import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';

class GoalSituationDialog extends StatelessWidget {
  final int playerCount;
  final GoalSituation detectedSituation;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const GoalSituationDialog({
    super.key,
    required this.playerCount,
    required this.detectedSituation,
    required this.onConfirm,
    required this.onCancel,
  });

  String _getSituationName(GoalSituation situation) {
    switch (situation) {
      case GoalSituation.powerPlay:
        return 'Power-Play';
      case GoalSituation.shortHanded:
        return 'Short-Handed';
      case GoalSituation.evenStrength:
        return 'Even-Strength';
    }
  }

  String _getSituationDescription(GoalSituation situation) {
    switch (situation) {
      case GoalSituation.powerPlay:
        return 'Power-play goals do not affect player +/- statistics since the scoring team has a numerical advantage.';
      case GoalSituation.shortHanded:
        return 'Short-handed goals follow normal +/- rules since the scoring team overcame a numerical disadvantage.';
      case GoalSituation.evenStrength:
        return 'Even-strength goals follow normal +/- rules.';
    }
  }

  Color _getSituationColor(GoalSituation situation) {
    switch (situation) {
      case GoalSituation.powerPlay:
        return Colors.orange;
      case GoalSituation.shortHanded:
        return Colors.red;
      case GoalSituation.evenStrength:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final situationName = _getSituationName(detectedSituation);
    final situationDescription = _getSituationDescription(detectedSituation);
    final situationColor = _getSituationColor(detectedSituation);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      title: Text(
        '$situationName Goal Detected',
        style: TextStyle(
          color: situationColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: situationColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: situationColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              'You selected $playerCount players on ice',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: situationColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Situation Details:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            situationDescription,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Is this correct?',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: situationColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('Confirm $situationName Goal'),
        ),
      ],
    );
  }
}
