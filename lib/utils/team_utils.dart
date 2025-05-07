import 'package:flutter/material.dart';

class TeamUtils {
  /// Returns a widget representing the team logo based on the team name
  /// If no specific logo is found, returns a generic placeholder
  static Widget getTeamLogo(String teamName, {double size = 40.0}) {
    // Convert team name to lowercase for case-insensitive comparison
    final name = teamName.toLowerCase();
    
    // Check for specific team names and return appropriate logo
    if (name.contains('waxers') || name == 'your team') {
      // Use the Waxers logo image
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Image.asset(
          'assets/logos/waxers_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    } else {
      // Generic opponent logo (red circle with first letter of team name)
      final firstLetter = teamName.isNotEmpty ? teamName[0].toUpperCase() : 'O';
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
            firstLetter,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.5,
            ),
          ),
        ),
      );
    }
  }

  /// Returns a widget with both team logos for a game
  static Widget getGameLogos(String yourTeam, String opponent, {double size = 40.0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        getTeamLogo(yourTeam, size: size),
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
        getTeamLogo(opponent, size: size),
      ],
    );
  }
}
