import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hockey_stats_app/models/team_model.dart';
import 'package:hockey_stats_app/services/team_context_service.dart';

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

      // Parse the teams array
      _teams = (jsonData['teams'] as List)
          .map((teamJson) => Team.fromJson(teamJson as Map<String, dynamic>))
          .toList();

      // Parse the default team
      _defaultTeam = Team.fromJson(jsonData['default'] as Map<String, dynamic>);

      _isInitialized = true;
      debugPrint('TeamUtils initialized successfully with ${_teams?.length} teams');
    } catch (e) {
      debugPrint('Error initializing TeamUtils: $e');
      // Create fallback teams and default in case of error
      _teams = [
        Team(
          id: 'waxers',
          name: 'Waxers',
          logoPath: 'assets/logos/waxers_logo.png',
          primaryColor: const Color(0xFF1E3A8A),
          secondaryColor: Colors.white,
        ),
        Team(
          id: 'your_team',
          name: 'Your Team',
          logoPath: 'assets/logos/your_team_logo.svg',
          primaryColor: const Color(0xFF059669),
          secondaryColor: Colors.white,
        ),
        Team(
          id: 'opponent',
          name: 'Opponent',
          logoPath: 'assets/logos/generic_logo.svg',
          primaryColor: const Color(0xFFDC2626),
          secondaryColor: Colors.white,
        ),
      ];
      
      _defaultTeam = Team(
        id: 'generic',
        name: 'Generic Team',
        logoPath: 'assets/logos/generic_logo.svg',
        primaryColor: Colors.grey,
        secondaryColor: Colors.white,
      );
      
      _isInitialized = true;
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

    final identifier = teamIdentifier.toLowerCase().trim();

    // Try to match by ID first
    for (final team in _teams!) {
      if (team.id.toLowerCase() == identifier) {
        return team;
      }
    }

    // If no match by ID, try to match by name (exact match first)
    for (final team in _teams!) {
      if (team.name.toLowerCase() == identifier) {
        return team;
      }
    }

    // If still no exact match, try partial name matching
    for (final team in _teams!) {
      if (team.name.toLowerCase().contains(identifier) || 
          identifier.contains(team.name.toLowerCase())) {
        return team;
      }
    }

    // If still no match, return the default team or a fallback
    return _defaultTeam ?? _getFallbackTeam(teamIdentifier);
  }

  /// Create a fallback team based on the team identifier
  static Team _getFallbackTeam(String teamIdentifier) {
    final cleanIdentifier = teamIdentifier.toLowerCase().trim();
    
    // Determine colors based on team type
    Color primaryColor;
    Color secondaryColor = Colors.white;
    
    if (cleanIdentifier.contains('waxers')) {
      primaryColor = const Color(0xFF1E3A8A); // Blue
    } else if (cleanIdentifier.contains('your') || cleanIdentifier.contains('home')) {
      primaryColor = const Color(0xFF059669); // Green
    } else if (cleanIdentifier.contains('opponent') || cleanIdentifier.contains('away')) {
      primaryColor = const Color(0xFFDC2626); // Red
    } else {
      primaryColor = const Color(0xFF6B7280); // Gray
    }

    return Team(
      id: cleanIdentifier.replaceAll(' ', '_'),
      name: teamIdentifier,
      logoPath: 'assets/logos/generic_logo.svg',
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
    );
  }

  /// Returns a widget representing the team logo based on the team name
  static Widget getTeamLogo(String teamName, {double size = 40.0, BuildContext? context}) {
    // Ensure initialization
    if (!_isInitialized && context != null) {
      initialize(context);
    }

    // Check if this matches the current team from the database
    return FutureBuilder<String>(
      future: _getCurrentTeamName(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final currentTeamName = snapshot.data!;
          
          // If the requested team name matches the current team, use database logo
          if (teamName.toLowerCase().trim() == currentTeamName.toLowerCase().trim()) {
            return FutureBuilder<String>(
              future: _getCurrentTeamLogoPath(),
              builder: (context, logoSnapshot) {
                if (logoSnapshot.hasData) {
                  final logoPath = logoSnapshot.data!;
                  return _buildTeamLogoFromPath(logoPath, size);
                }
                // While loading, show fallback
                return _buildFallbackLogoForCurrentTeam(teamName, size);
              },
            );
          } else {
            // For any team that is NOT the current team, always show "O" for opponent
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626), // Red color for opponent
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
        }
        
        // While loading current team name, check if it's explicitly "opponent"
        if (teamName.toLowerCase().trim() == 'opponent') {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626), // Red color for opponent
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
        
        // For other cases while loading, use existing JSON-based lookup
        final team = getTeam(teamName, context: context);
        return _buildTeamLogoWidget(team, size);
      },
    );
  }

  /// Build the actual logo widget with proper error handling
  static Widget _buildTeamLogoWidget(Team team, double size) {
    if (team.logoPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        team.logoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (BuildContext context) => _buildFallbackLogo(team, size),
      );
    } else {
      // Handle PNG and other image formats
      return Image.asset(
        team.logoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(team, size),
      );
    }
  }

  /// Build a fallback logo when the image fails to load
  static Widget _buildFallbackLogo(Team team, double size) {
    final firstLetter = team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T';
    
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
              color: Colors.grey[600],
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

  /// Get all available teams
  static List<Team> getAllTeams({BuildContext? context}) {
    if (!_isInitialized && context != null) {
      initialize(context);
    }
    return _teams ?? [];
  }

  /// Add a new team (useful for adding teams with different icons)
  static void addTeam(Team team) {
    if (_teams == null) {
      _teams = [];
    }
    
    // Remove existing team with same ID if it exists
    _teams!.removeWhere((existingTeam) => existingTeam.id == team.id);
    
    // Add the new team
    _teams!.add(team);
    
    debugPrint('Added team: ${team.name} with logo: ${team.logoPath}');
  }

  /// Check if a team exists
  static bool teamExists(String teamIdentifier) {
    if (_teams == null) return false;
    
    final identifier = teamIdentifier.toLowerCase().trim();
    
    return _teams!.any((team) => 
      team.id.toLowerCase() == identifier || 
      team.name.toLowerCase() == identifier
    );
  }

  /// Get the current team name from the database
  static Future<String> _getCurrentTeamName() async {
    try {
      final teamContextService = TeamContextService();
      return await teamContextService.getCurrentTeamName();
    } catch (e) {
      return 'Your Team'; // Fallback
    }
  }

  /// Get the current team logo path from the database
  static Future<String> _getCurrentTeamLogoPath() async {
    try {
      final teamContextService = TeamContextService();
      return await teamContextService.getCurrentTeamLogoPath();
    } catch (e) {
      return 'assets/logos/generic_logo.svg'; // Fallback
    }
  }

  /// Build team logo widget from a logo path
  static Widget _buildTeamLogoFromPath(String logoPath, double size) {
    if (logoPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        logoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (BuildContext context) => _buildGenericFallbackLogo(size),
      );
    } else {
      // Handle PNG and other image formats
      return Image.asset(
        logoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildGenericFallbackLogo(size),
      );
    }
  }

  /// Build a fallback logo for the current team
  static Widget _buildFallbackLogoForCurrentTeam(String teamName, double size) {
    final firstLetter = teamName.isNotEmpty ? teamName[0].toUpperCase() : 'T';
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF059669), // Green for current team
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

  /// Build a generic fallback logo
  static Widget _buildGenericFallbackLogo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6B7280), // Gray
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
          'T',
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
