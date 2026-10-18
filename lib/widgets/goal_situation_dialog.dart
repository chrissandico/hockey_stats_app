import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';

class GoalSituationDialog extends StatefulWidget {
  final int playerCount;
  final GoalSituation detectedSituation;
  final ValueChanged<GoalSituation>? onConfirmSituation;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const GoalSituationDialog({
    super.key,
    required this.playerCount,
    required this.detectedSituation,
    required this.onConfirm,
    required this.onCancel,
    this.onConfirmSituation,
  });

  @override
  State<GoalSituationDialog> createState() => _GoalSituationDialogState();
}

class _GoalSituationDialogState extends State<GoalSituationDialog> {
  late GoalSituation _selectedSituation;

  @override
  void initState() {
    super.initState();
    _selectedSituation = widget.detectedSituation;
  }

  String _getSituationName(GoalSituation situation) {
    switch (situation) {
      case GoalSituation.powerPlay:
        return 'Power-Play';
      case GoalSituation.shortHanded:
        return 'Penalty Kill / Short-Handed';
      case GoalSituation.evenStrength:
        return 'Even-Strength (e.g., 4v4, 3v3)';
    }
  }

  String _getSituationShortName(GoalSituation situation) {
    switch (situation) {
      case GoalSituation.powerPlay:
        return 'Power Play';
      case GoalSituation.shortHanded:
        return 'Penalty Kill';
      case GoalSituation.evenStrength:
        return 'Even Strength';
    }
  }

  String _getSituationDescription(GoalSituation situation) {
    switch (situation) {
      case GoalSituation.powerPlay:
        return 'Power-play goals do not affect player +/- statistics since the scoring team has a numerical advantage.';
      case GoalSituation.shortHanded:
        return 'Short-handed goals follow normal +/- rules since the scoring team overcome a numerical disadvantage.';
      case GoalSituation.evenStrength:
        return 'Even-strength goals follow normal +/- rules (equal skaters on ice for both teams).';
    }
  }

  Color _getSituationColor(GoalSituation situation) {
    switch (situation) {
      case GoalSituation.powerPlay:
        return Colors.orange.shade800;
      case GoalSituation.shortHanded:
        return Colors.red.shade700;
      case GoalSituation.evenStrength:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _getSituationColor(_selectedSituation);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      title: const Text(
        'Confirm Goal Situation',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You selected ${widget.playerCount} skaters on ice.\nFewer than 5 skaters can occur during Even Strength (e.g., 4v4 or 3v3 OT), Penalty Kill, or Power Play.',
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Situation:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            // Option 1: Even Strength
            _buildSituationOption(
              situation: GoalSituation.evenStrength,
              title: 'Even Strength',
              subtitle: 'Equal skaters on ice (5v5, 4v4, 3v3 OT)',
              color: Colors.green,
            ),
            const SizedBox(height: 6),

            // Option 2: Penalty Kill
            _buildSituationOption(
              situation: GoalSituation.shortHanded,
              title: 'Penalty Kill (Short-Handed)',
              subtitle: 'Your team has fewer skaters than opponent',
              color: Colors.red,
            ),
            const SizedBox(height: 6),

            // Option 3: Power Play
            _buildSituationOption(
              situation: GoalSituation.powerPlay,
              title: 'Power Play',
              subtitle: 'Your team has more skaters than opponent',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),

            Text(
              _getSituationDescription(_selectedSituation),
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirmSituation?.call(_selectedSituation);
            widget.onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: currentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('Confirm ${_getSituationShortName(_selectedSituation)}'),
        ),
      ],
    );
  }

  Widget _buildSituationOption({
    required GoalSituation situation,
    required String title,
    required String subtitle,
    required MaterialColor color,
  }) {
    final isSelected = _selectedSituation == situation;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSituation = situation;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color.shade700 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<GoalSituation>(
              value: situation,
              groupValue: _selectedSituation,
              activeColor: color.shade700,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedSituation = val;
                  });
                }
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                      color: isSelected ? color.shade900 : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? color.shade800 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

