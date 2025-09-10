import 'package:flutter/material.dart';
import 'package:hockey_stats_app/services/team_auth_service.dart';
import 'package:hockey_stats_app/utils/team_utils.dart';

class TeamLoginScreen extends StatefulWidget {
  final Function(String) onLoginSuccess;

  const TeamLoginScreen({
    Key? key,
    required this.onLoginSuccess,
  }) : super(key: key);

  @override
  _TeamLoginScreenState createState() => _TeamLoginScreenState();
}

class _TeamLoginScreenState extends State<TeamLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _teamAuthService = TeamAuthService();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberPassword = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkExistingTeam();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingTeam() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if a team is already selected
      final hasTeam = await _teamAuthService.hasTeam();
      if (hasTeam) {
        final teamId = await _teamAuthService.getCurrentTeamId();
        if (teamId != null) {
          // If a team is already selected, skip the login screen
          widget.onLoginSuccess(teamId);
        }
      }
    } catch (e) {
      print('Error checking existing team: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final password = _passwordController.text.trim();
      final teamId = await _teamAuthService.validateTeamPassword(password);

      if (teamId != null) {
        // If remember password is checked, save the team ID
        if (_rememberPassword) {
          await _teamAuthService.setCurrentTeamId(teamId);
        }
        
        // Call the onLoginSuccess callback with the team ID
        widget.onLoginSuccess(teamId);
      } else {
        setState(() {
          _errorMessage = 'Invalid team password. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
      print('Login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Login'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Logo or team image
                    Center(
                      child: TeamUtils.getTeamLogo('your_team', size: 120, context: context),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Hockey Stats App',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your team password to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Team Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your team password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Remember password checkbox
                    CheckboxListTile(
                      title: const Text('Remember team'),
                      value: _rememberPassword,
                      onChanged: (value) {
                        setState(() {
                          _rememberPassword = value ?? true;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    // Error message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // Login button
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'LOGIN',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
