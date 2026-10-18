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
    final logo = (row.length > 3 && row[3] != null && row[3].toString().trim().isNotEmpty)
        ? row[3].toString().trim()
        : 'waxers_logo.png';

    return Team(
      id: row[0]?.toString().trim() ?? '',
      name: row[1]?.toString().trim() ?? '',
      password: row[2]?.toString().trim() ?? '',
      logoFileName: logo,
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

  /// Clear the in-memory cached teams list
  void clearCachedTeams() {
    _cachedTeams = null;
  }

  /// Get a list of teams from the Google Sheets "Teams" sheet
  Future<List<Team>> fetchTeams({bool forceRefresh = false}) async {
    // Return cached teams if available and not forcing refresh
    if (!forceRefresh && _cachedTeams != null && _cachedTeams!.isNotEmpty) {
      return _cachedTeams!;
    }

    try {
      // Get the service account auth instance
      final serviceAuth = await ServiceAccountAuth.instance;
      
      // Construct the URL to fetch the Teams sheet
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/Teams!A2:D'
      );
      
      // Make the authenticated request
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
        } else {
          // Parse the teams from the sheet
          _cachedTeams = values.map((row) {
            if (row.length >= 3) {
              final team = Team.fromSheetRow(row);
              if (team.id.isNotEmpty && team.password.isNotEmpty) {
                return team;
              }
            }
            return null;
          }).whereType<Team>().toList();
          
          print('Fetched ${_cachedTeams!.length} teams from the Teams sheet');
        }
      } else {
        print('Failed to fetch teams: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching teams from Google Sheets: $e');
      print('This could be due to:');
      print('1. Service account configuration issues');
      print('2. Network connectivity problems');
      print('3. Google Sheets API access issues');
      print('4. Missing or incorrect spreadsheet permissions');
    }
    
    return _cachedTeams ?? [];
  }

  /// Validate team password and return team ID if valid
  Future<String?> validateTeamPassword(String password) async {
    try {
      final cleanPassword = password.trim();
      if (cleanPassword.isEmpty) return null;

      // Always force refresh teams from Google Sheets when validating password
      final teams = await fetchTeams(forceRefresh: true);
      
      print('Validating password against ${teams.length} teams from Google Sheets');

      // Find team with matching password (case-insensitive & trimmed)
      for (final team in teams) {
        final teamPassword = team.password.trim();
        if (teamPassword.toLowerCase() == cleanPassword.toLowerCase()) {
          print('Password match found for team ID: "${team.id}" (${team.name})');
          return team.id;
        }
      }
      
      print('No team password matched "$cleanPassword"');
      return null;
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
      clearCachedTeams();
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
