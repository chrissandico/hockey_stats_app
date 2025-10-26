import 'package:flutter/material.dart';
import 'package:hockey_stats_app/services/wakelock_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _keepScreenAwake = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final keepAwake = await WakelockService.getKeepScreenAwakePreference();
    if (mounted) {
      setState(() {
        _keepScreenAwake = keepAwake;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateKeepScreenAwakeSetting(bool value) async {
    await WakelockService.setKeepScreenAwakePreference(value);
    if (mounted) {
      setState(() {
        _keepScreenAwake = value;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value 
              ? 'Screen will stay awake during stats tracking'
              : 'Screen will follow normal timeout during stats tracking'
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Display Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Keep Screen Awake'),
                          subtitle: const Text(
                            'Prevents screen from turning off automatically while tracking stats'
                          ),
                          value: _keepScreenAwake,
                          onChanged: _updateKeepScreenAwakeSetting,
                          secondary: const Icon(Icons.screen_lock_portrait),
                        ),
                        if (_keepScreenAwake) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text(
                              'Note: You can still manually lock your screen, and the screen will return to normal timeout when you leave the stats screen.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}