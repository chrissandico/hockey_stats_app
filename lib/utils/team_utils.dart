import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Import flutter_svg
import 'package:hockey_stats_app/models/team_model.dart';

class TeamUtils {
  static List<Team>? _teams;
  static Team? _defaultTeam;
  static bool _isInitialized = false;

  /// Initialize the team utils by loading the team data from the JSON file
  static Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;

    try {
      // Load the JSON file
      final jsonString = await DefaultAssetBundle.of(context).loadString('assets/data/team_logos.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Parse the teams
      _teams = (jsonData['teams'] as List)
          .map((teamJson) => Team.fromJson(teamJson as Map<String, dynamic>))
          .toList();

      // Parse the default team
      _defaultTeam = Team.fromJson(jsonData['default'] as Map<String, dynamic>);

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing TeamUtils: $e');
      // Create a fallback default team in case of error
      _defaultTeam = Team(
        id: 'default',
        name: 'Default',
        logoPath: 'assets/logos/generic_logo.svg',
        primaryColor: Colors.grey,
        secondaryColor: Colors.white,
      );
    }
  }

  /// Get a team by its identifier (id or name)
  static Team getTeam(String teamIdentifier, {BuildContext? context}) {
    // If not initialized and context is provided, try to initialize
    if (!_isInitialized && context != null) {
      // We can't await here, so we'll just trigger the initialization
      // and return a fallback for now
      initialize(context);
    }

    if (_teams == null || _teams!.isEmpty) {
      return _getFallbackTeam(teamIdentifier);
    }

    final identifier = teamIdentifier.toLowerCase();

    // Try to match by ID first
    for (final team in _teams!) {
      if (team.id.toLowerCase() == identifier) {
        return team;
      }
    }

    // If no match by ID, try to match by name
    for (final team in _teams!) {
      if (team.name.toLowerCase().contains(identifier)) {
        return team;
      }
    }

    // If still no match, return the default team or a fallback
    return _defaultTeam ?? _getFallbackTeam(teamIdentifier);
  }

  /// Create a fallback team based on the team identifier
  static Team _getFallbackTeam(String teamIdentifier) {
    final firstLetter = teamIdentifier.isNotEmpty ? teamIdentifier[0].toUpperCase() : 'T';
    final isYourTeam = teamIdentifier.toLowerCase().contains('your') || 
                       teamIdentifier.toLowerCase().contains('waxers');

    return Team(
      id: teamIdentifier.toLowerCase().replaceAll(' ', '_'),
      name: teamIdentifier,
      logoPath: 'assets/logos/generic_logo.svg',
      primaryColor: isYourTeam ? Colors.blue : Colors.red,
      secondaryColor: Colors.white,
    );
  }

  /// Returns a widget representing the team logo based on the team name
  static Widget getTeamLogo(String teamName, {double size = 40.0, BuildContext? context}) {
    // Special case for 'Opponent' or any opponent team - always return a simple "O" logo
    if (teamName == 'Opponent' || 
        (teamName != 'Waxers' && teamName != 'Your Team' && !teamName.toLowerCase().contains('waxers'))) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'O',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.5,
            ),
          ),
        ),
      );
    }
    
    // For all other teams, use the existing logic
    final team = getTeam(teamName, context: context);
    
    if (team.logoPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        team.logoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (BuildContext context) => Container( // Fallback for SVG loading issue
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: team.primaryColor.withOpacity(0.1), // Lighter fallback color
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.broken_image, size: size * 0.6, color: team.primaryColor),
          )
        ),
      );
    } else { // This is for non-SVG images like PNG
      return Image.asset(
        team.logoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to the current letter-based logo if image fails to load
          final firstLetter = teamName.isNotEmpty ? teamName[0].toUpperCase() : 'T';
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: team.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: team.secondaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.5,
                ),
              ),
            ),
          );
        },
      );
    } // This closing brace was missing for the 'else' block of the if-svg condition
  }

  /// Returns a widget with both team logos for a game
  static Widget getGameLogos(String yourTeam, String opponent, {double size = 40.0, BuildContext? context}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        getTeamLogo(yourTeam, size: size, context: context),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'VS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: size * 0.4,
            ),
          ),
        ),
        getTeamLogo(opponent, size: size, context: context),
      ],
    );
  }

  /// Get the primary color for a team
  static Color getPrimaryColor(String teamName, {BuildContext? context}) {
    return getTeam(teamName, context: context).primaryColor;
  }

  /// Get the secondary color for a team
  static Color getSecondaryColor(String teamName, {BuildContext? context}) {
    return getTeam(teamName, context: context).secondaryColor;
  }
}
