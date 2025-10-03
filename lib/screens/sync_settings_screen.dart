import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';

/// Screen for configuring sync preferences
/// Allows users to choose which event types should be synced to Google Sheets
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  late SyncPreferences _preferences;
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
      _preferences = prefsBox.get('user_prefs') ?? SyncPreferences();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading sync preferences: $e');
      _preferences = SyncPreferences();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefsBox = Hive.box<SyncPreferences>('syncPreferences');
      await prefsBox.put('user_prefs', _preferences);
      
      setState(() {
        _hasChanges = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync preferences saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving sync preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updatePreference(String type, bool value) {
    setState(() {
      switch (type) {
        case 'goals':
          _preferences.syncGoals = value;
          break;
        case 'shots':
          _preferences.syncShots = value;
          break;
        case 'penalties':
          _preferences.syncPenalties = value;
          break;
        case 'attendance':
          _preferences.syncAttendance = value;
          break;
        case 'onlyImportant':
          _preferences.syncOnlyImportantEvents = value;
          break;
      }
      _hasChanges = true;
    });
  }

  Widget _buildSyncOption({
    required String title,
    required String subtitle,
    required bool value,
    required String type,
    IconData? icon,
    Color? iconColor,
    bool? isRecommended,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? Colors.blue, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(title)),
            if (isRecommended == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: const Text(
                  'Recommended',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (newValue) => _updatePreference(type, newValue),
        activeColor: Colors.blue,
      ),
    );
  }

  Widget _buildSyncSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Current Sync Configuration',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _preferences.getSyncSummary(),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            'Only selected event types will be sent to Google Sheets. This helps reduce API usage and keeps your spreadsheet focused on what matters most.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _savePreferences,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // Header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose What to Sync',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Select which event types should be automatically synced to Google Sheets. This helps reduce API usage and keeps your data focused.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sync options
                  _buildSyncOption(
                    title: 'Goals',
                    subtitle: 'Always sync goals - the most important events',
                    value: _preferences.syncGoals,
                    type: 'goals',
                    icon: Icons.sports_score,
                    iconColor: Colors.green,
                    isRecommended: true,
                  ),
                  
                  _buildSyncOption(
                    title: 'Shots',
                    subtitle: 'Sync all shots (including saves and misses)',
                    value: _preferences.syncShots,
                    type: 'shots',
                    icon: Icons.sports_hockey,
                    iconColor: Colors.blue,
                    isRecommended: true,
                  ),
                  
                  _buildSyncOption(
                    title: 'Penalties',
                    subtitle: 'Sync penalty events and infractions',
                    value: _preferences.syncPenalties,
                    type: 'penalties',
                    icon: Icons.sports,
                    iconColor: Colors.orange,
                    isRecommended: true,
                  ),
                  
                  _buildSyncOption(
                    title: 'Attendance',
                    subtitle: 'Sync player attendance records (can generate many API calls)',
                    value: _preferences.syncAttendance,
                    type: 'attendance',
                    icon: Icons.people,
                    iconColor: Colors.purple,
                    isRecommended: false,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Divider
                  const Divider(thickness: 1, indent: 16, endIndent: 16),
                  
                  const SizedBox(height: 8),
                  
                  // Advanced options
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Advanced Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _buildSyncOption(
                    title: 'Sync Only Important Events',
                    subtitle: 'Only sync goals and penalties (ignores regular shots)',
                    value: _preferences.syncOnlyImportantEvents,
                    type: 'onlyImportant',
                    icon: Icons.star,
                    iconColor: Colors.amber,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Summary
                  _buildSyncSummary(),
                  
                  // Warning about attendance
                  if (_preferences.syncAttendance)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Attendance sync can generate many API calls. Consider disabling if you experience rate limiting issues.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _savePreferences,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
