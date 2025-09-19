import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:hockey_stats_app/services/service_account_auth.dart';

/// Model class for team data
class Team {
  final String id;
  final String name;
  final String password;
  final String logoFileName;

  Team({
    required this.id,
    required this.name,
    required this.password,
    required this.logoFileName,
  });

  factory Team.fromSheetRow(List<dynamic> row) {
    return Team(
      id: row[0]?.toString() ?? '',
      name: row[1]?.toString() ?? '',
      password: row[2]?.toString() ?? '',
      logoFileName: row[3]?.toString() ?? 'waxers_logo.png', // Use PNG instead of corrupted SVG
    );
  }

  @override
  String toString() => 'Team(id: $id, name: $name, logoFileName: $logoFileName)';
}

/// Service for team authentication and management
class TeamAuthService {
  static const String _spreadsheetId = '1u4olfiYFjXW0Z88U3Q1wOxI7gz04KYbg6LNn8h-rfno';
  static const String _currentTeamKey = 'current_team_id';
  static const String _serviceAccountPath = 'assets/config/service_account.json';
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  List<Team>? _cachedTeams;
  String? _currentTeamId;

  /// Get a list of teams from the Google Sheets "Teams" sheet
  Future<List<Team>> fetchTeams() async {
    // Return cached teams if available
    if (_cachedTeams != null) {
      return _cachedTeams!;
    }

    try {
      // Get the service account auth instance
      final serviceAuth = await ServiceAccountAuth.instance;
      
      // Construct the URL to fetch the Teams sheet
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/Teams!A2:D'
      );
      
      // Make the authenticated request using the new method
      final response = await serviceAuth.makeAuthenticatedRequest(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        // Parse the response
        final Map<String, dynamic> data = json.decode(response.body);
        final List<List<dynamic>> values = List<List<dynamic>>.from(data['values'] ?? []);
        
        if (values.isEmpty) {
          print('No teams found in the Teams sheet');
          throw Exception('No teams found in the Teams sheet');
        } else {
          // Parse the teams from the sheet
          _cachedTeams = values.map((row) {
            if (row.length >= 3) {
              return Team.fromSheetRow(row);
            }
            return null;
          }).whereType<Team>().toList();
          
          print('Fetched ${_cachedTeams!.length} teams from the Teams sheet');
        }
      } else {
        print('Failed to fetch teams: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch teams: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching teams from Google Sheets: $e');
      print('This could be due to:');
      print('1. Service account configuration issues');
      print('2. Network connectivity problems');
      print('3. Google Sheets API access issues');
      print('4. Missing or incorrect spreadsheet permissions');
      
      // Don't rethrow - instead return empty list to allow offline operation
      // The team password validation will still work with cached data or fallback
      _cachedTeams = [];
      return _cachedTeams!;
    }
    
    return _cachedTeams!;
  }

  /// Validate team password and return team ID if valid
  Future<String?> validateTeamPassword(String password) async {
    try {
      // Fetch teams
      final teams = await fetchTeams();
      
      // Find team with matching password
      final team = teams.firstWhere(
        (team) => team.password == password,
        orElse: () => Team(id: '', name: '', password: '', logoFileName: 'waxers_logo.png'),
      );
      
      // Return team ID if found, null otherwise
      return team.id.isNotEmpty ? team.id : null;
    } catch (e) {
      print('Error validating team password: $e');
      return null;
    }
  }

  /// Get the current team ID from secure storage
  Future<String?> getCurrentTeamId() async {
    if (_currentTeamId != null) {
      return _currentTeamId;
    }
    
    try {
      _currentTeamId = await _secureStorage.read(key: _currentTeamKey);
      return _currentTeamId;
    } catch (e) {
      print('Error getting current team: $e');
      return null;
    }
  }

  /// Set the current team ID in secure storage
  Future<void> setCurrentTeamId(String teamId) async {
    try {
      await _secureStorage.write(key: _currentTeamKey, value: teamId);
      _currentTeamId = teamId;
    } catch (e) {
      print('Error setting current team: $e');
    }
  }

  /// Get the current team details
  Future<Team?> getCurrentTeam() async {
    final teamId = await getCurrentTeamId();
    if (teamId == null) {
      return null;
    }
    
    final teams = await fetchTeams();
    return teams.firstWhere(
      (team) => team.id == teamId,
      orElse: () => Team(id: '', name: '', password: '', logoFileName: 'waxers_logo.png'),
    );
  }

  /// Clear the current team from secure storage
  Future<void> clearCurrentTeam() async {
    try {
      await _secureStorage.delete(key: _currentTeamKey);
      _currentTeamId = null;
    } catch (e) {
      print('Error clearing current team: $e');
    }
  }

  /// Check if a team is currently selected
  Future<bool> hasTeam() async {
    final teamId = await getCurrentTeamId();
    return teamId != null && teamId.isNotEmpty;
  }
}
