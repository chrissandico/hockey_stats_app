import 'package:hockey_stats_app/services/team_auth_service.dart';

/// Service to manage current team context throughout the app
class TeamContextService {
  static final TeamContextService _instance = TeamContextService._internal();
  factory TeamContextService() => _instance;
  TeamContextService._internal();

  final TeamAuthService _teamAuthService = TeamAuthService();
  Team? _currentTeam;

  /// Get the current team details
  Future<Team?> getCurrentTeam() async {
    // Return cached team if available
    if (_currentTeam != null) {
      return _currentTeam;
    }

    // Fetch from TeamAuthService
    _currentTeam = await _teamAuthService.getCurrentTeam();
    return _currentTeam;
  }

  /// Get the current team's display name
  Future<String> getCurrentTeamName() async {
    final team = await getCurrentTeam();
    return team?.name ?? 'Your Team';
  }

  /// Get the current team's logo file name
  Future<String> getCurrentTeamLogoFileName() async {
    final team = await getCurrentTeam();
    return team?.logoFileName ?? 'generic_logo.svg';
  }

  /// Get the current team's logo path for assets
  Future<String> getCurrentTeamLogoPath() async {
    final logoFileName = await getCurrentTeamLogoFileName();
    return 'assets/logos/$logoFileName';
  }

  /// Get the current team ID
  Future<String?> getCurrentTeamId() async {
    final team = await getCurrentTeam();
    return team?.id;
  }

  /// Clear the cached team (call this when team changes)
  void clearCache() {
    _currentTeam = null;
  }

  /// Set the current team (call this after successful login)
  Future<void> setCurrentTeam(String teamId) async {
    await _teamAuthService.setCurrentTeamId(teamId);
    clearCache(); // Clear cache so it gets refreshed next time
  }

  /// Check if a team is currently selected
  Future<bool> hasTeam() async {
    return await _teamAuthService.hasTeam();
  }

  /// Clear the current team
  Future<void> clearCurrentTeam() async {
    await _teamAuthService.clearCurrentTeam();
    clearCache();
  }
}
