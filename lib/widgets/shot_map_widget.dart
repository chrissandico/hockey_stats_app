import 'package:flutter/material.dart';
import 'package:hockey_stats_app/models/data_models.dart';

class ShotMapWidget extends StatelessWidget {
  final List<GameEvent> gameEvents;
  final Function(double x, double y)? onShotLocationTapped;

  const ShotMapWidget({
    super.key,
    required this.gameEvents,
    this.onShotLocationTapped,
  });

  @override
  Widget build(BuildContext context) {
    final shotEvents = gameEvents.where((e) => e.eventType == 'Shot').toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blueGrey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.map_outlined, color: Colors.cyanAccent),
                    SizedBox(width: 8),
                    Text(
                      'Rink Shot Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildLegendItem(Colors.greenAccent, 'Goal'),
                    const SizedBox(width: 12),
                    _buildLegendItem(Colors.lightBlueAccent, 'Shot'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 2.0, // Standard hockey rink aspect ratio (2:1)
              child: GestureDetector(
                onTapUp: (details) {
                  if (onShotLocationTapped != null) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPos = details.localPosition;
                    final normalizedX = (localPos.dx / box.size.width).clamp(0.0, 1.0);
                    final normalizedY = (localPos.dy / box.size.height).clamp(0.0, 1.0);
                    onShotLocationTapped!(normalizedX, normalizedY);
                  }
                },
                child: CustomPaint(
                  painter: RinkPainter(shots: shotEvents),
                  child: Container(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Shots Recorded: ${shotEvents.length} (${shotEvents.where((e) => e.isGoal == true).length} Goals)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class RinkPainter extends CustomPainter {
  final List<GameEvent> shots;

  RinkPainter({required this.shots});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Ice
    final icePaint = Paint()
      ..color = const Color(0xFFEBF5FB)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final redLinePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final blueLinePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Rink Border (Rounded Rectangle)
    final RRect rinkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h * 0.25),
    );

    canvas.drawRRect(rinkRect, icePaint);
    canvas.drawRRect(rinkRect, borderPaint);

    // Center Red Line
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), redLinePaint);

    // Blue Lines
    canvas.drawLine(Offset(w * 0.35, 0), Offset(w * 0.35, h), blueLinePaint);
    canvas.drawLine(Offset(w * 0.65, 0), Offset(w * 0.65, h), blueLinePaint);

    // Goal Lines
    canvas.drawLine(Offset(w * 0.08, h * 0.1), Offset(w * 0.08, h * 0.9), redLinePaint);
    canvas.drawLine(Offset(w * 0.92, h * 0.1), Offset(w * 0.92, h * 0.9), redLinePaint);

    // Center Circle
    final centerCirclePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), h * 0.18, centerCirclePaint);

    // Plot Shots
    for (final shot in shots) {
      // Default to center offensive zone if coordinates missing
      double x = shot.shotX ?? (shot.team == 'opponent' ? 0.25 : 0.75);
      double y = shot.shotY ?? 0.5;

      final shotPoint = Offset(x * w, y * h);
      final isGoal = shot.isGoal == true;

      final dotPaint = Paint()
        ..color = isGoal ? Colors.green : Colors.blue.shade700
        ..style = PaintingStyle.fill;

      final haloPaint = Paint()
        ..color = isGoal ? Colors.greenAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(shotPoint, isGoal ? 6.0 : 4.5, dotPaint);
      canvas.drawCircle(shotPoint, isGoal ? 9.0 : 6.5, haloPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RinkPainter oldDelegate) => true;
}
