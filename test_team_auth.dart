import 'package:flutter/material.dart';
import 'package:hockey_stats_app/services/team_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Testing team authentication...');
  
  final teamAuthService = TeamAuthService();
  
  try {
    print('Fetching teams from Google Sheets...');
    final teams = await teamAuthService.fetchTeams();
    
    print('Found ${teams.length} teams:');
    for (final team in teams) {
      print('- Team ID: ${team.id}, Name: ${team.name}, Password: ${team.password}');
    }
    
    if (teams.isNotEmpty) {
      print('\nTesting password validation with first team...');
      final firstTeam = teams.first;
      final validatedTeamId = await teamAuthService.validateTeamPassword(firstTeam.password);
      
      if (validatedTeamId != null) {
        print('✅ Password validation successful! Team ID: $validatedTeamId');
      } else {
        print('❌ Password validation failed');
      }
    }
    
  } catch (e) {
    print('❌ Error testing team authentication: $e');
  }
}
