import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/widgets/shot_map_widget.dart';
import 'package:hockey_stats_app/widgets/analytics_charts_widget.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  final String gameId;
  final String teamId;

  const AnalyticsDashboardScreen({
    super.key,
    required this.gameId,
    required this.teamId,
  });

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final playersBox = Hive.box<Player>('players');
    final players = playersBox.values.where((p) => p.teamId == widget.teamId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.blueGrey.shade900,
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<GameEvent>('gameEvents').listenable(),
        builder: (context, Box<GameEvent> box, _) {
          final gameEvents = box.values.where((e) => e.gameId == widget.gameId).toList();

          if (gameEvents.isEmpty) {
            return const Center(
              child: Text(
                'No events logged for this game yet.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShotMapWidget(gameEvents: gameEvents),
                const SizedBox(height: 16),
                AnalyticsChartsWidget(
                  gameEvents: gameEvents,
                  players: players,
                  teamId: widget.teamId,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
