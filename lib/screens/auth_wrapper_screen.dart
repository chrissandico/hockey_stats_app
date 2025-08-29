import 'package:flutter/material.dart';
import 'package:hockey_stats_app/screens/game_selection_screen.dart';
import 'package:hockey_stats_app/screens/team_login_screen.dart';
import 'package:hockey_stats_app/services/team_auth_service.dart';
import 'package:provider/provider.dart';

/// A wrapper screen that handles the authentication flow.
/// It shows either the team login screen or the game selection screen
/// based on the authentication state.
class AuthWrapperScreen extends StatefulWidget {
  const AuthWrapperScreen({Key? key}) : super(key: key);

  @override
  _AuthWrapperScreenState createState() => _AuthWrapperScreenState();
}

class _AuthWrapperScreenState extends State<AuthWrapperScreen> {
  final TeamAuthService _teamAuthService = TeamAuthService();
  String? _currentTeamId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkCurrentTeam();
  }

  Future<void> _checkCurrentTeam() async {
    try {
      final teamId = await _teamAuthService.getCurrentTeamId();
      setState(() {
        _currentTeamId = teamId;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking current team: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleLoginSuccess(String teamId) {
    setState(() {
      _currentTeamId = teamId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If we have a current team ID, show the game selection screen
    if (_currentTeamId != null) {
      return GameSelectionScreen(
        teamId: _currentTeamId!,
        onSignOut: () {
          // Handle sign out by clearing the current team
          _teamAuthService.clearCurrentTeam().then((_) {
            setState(() {
              _currentTeamId = null;
            });
          });
        },
      );
    }

    // Otherwise, show the team login screen
    return TeamLoginScreen(
      onLoginSuccess: _handleLoginSuccess,
    );
  }
}
