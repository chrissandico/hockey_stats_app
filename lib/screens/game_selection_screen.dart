import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:hockey_stats_app/models/data_models.dart'; // Import your data models
import 'package:hockey_stats_app/screens/log_stats_screen.dart'; // We'll create a new screen to hold the logging buttons
import 'package:hockey_stats_app/services/sheets_service.dart'; // Import SheetsService for syncing
import 'package:uuid/uuid.dart'; // Import for generating UUIDs
import 'package:hockey_stats_app/main.dart' as main_logic; // To access functions from main.dart
import 'package:hockey_stats_app/screens/attendance_dialog.dart'; // Import attendance dialog
// Enum for different screen states
enum _ScreenState { initialLoading, syncFailed, dataLoaded, noGamesFound }

// This screen will allow the user to select a game from the local database.
class GameSelectionScreen extends StatefulWidget {
  final String teamId;
  final VoidCallback? onSignOut;

  const GameSelectionScreen({
    super.key, 
    required this.teamId,
    this.onSignOut,
  });

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  // Hive Box for Games
  late Box<Game> gamesBox;
  List<Game> availableGames = [];
  Game? _selectedGame;
  
  // Service for syncing with Google Sheets
  final SheetsService _sheetsService = SheetsService();
  // bool _isLoading = false; // Replaced by _screenState

  // New state variables for UI and data flow management
  _ScreenState _screenState = _ScreenState.initialLoading;
  String? _errorMessage;
  bool _isPerformingAsyncOperation = false; // General loading flag for buttons etc.

  // Helper method to convert game type codes to readable text
  String _getGameTypeText(String gameType) {
    switch (gameType.toUpperCase()) {
      case 'E':
        return 'Exhibition';
      case 'R':
        return 'Regular Season';
      case 'T':
        return 'Tournament';
      default:
        return 'Regular Season'; // Default fallback
    }
  }

  // Helper method to get color for game type badges
  Color _getGameTypeColor(String gameType) {
    switch (gameType.toUpperCase()) {
      case 'E':
        return Colors.orange; // Exhibition
      case 'R':
        return Colors.blue; // Regular Season
      case 'T':
        return Colors.purple; // Tournament
      default:
        return Colors.blue; // Default fallback
    }
  }


  @override
  void initState() {
    super.initState();
    gamesBox = Hive.box<Game>('games');
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    if (!mounted) return;
    setState(() {
      _screenState = _ScreenState.initialLoading;
    });

    // With service account authentication, we always try to sync automatically
    final syncResult = await main_logic.attemptInitialDataSyncIfSignedIn();
    if (!mounted) return;

    _loadGamesInternal(); // Load games from Hive regardless of sync outcome

    if (syncResult['status'] == 'sync_success') {
      // Data synced successfully
      setState(() {
        _screenState = availableGames.isEmpty ? _ScreenState.noGamesFound : _ScreenState.dataLoaded;
        _errorMessage = null;
      });
    } else {
      // Sync failed, but show local games if available
      setState(() {
        _errorMessage = syncResult['message'] as String?;
        _screenState = availableGames.isEmpty ? _ScreenState.noGamesFound : _ScreenState.syncFailed;
      });
    }
  }

  // Renamed _loadGames to avoid conflict and clarify it's an internal step
  void _loadGamesInternal() {
    // This method doesn't call setState directly.
    // The calling method (_initializeScreen or after add/edit/delete) is responsible for setState.
    
    // Filter games by the current team ID and sort by date proximity to today
    availableGames = gamesBox.values
        .where((game) => game.teamId == widget.teamId)
        .toList()
        ..sort((a, b) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dateA = DateTime(a.date.year, a.date.month, a.date.day);
          final dateB = DateTime(b.date.year, b.date.month, b.date.day);
          
          final diffA = dateA.difference(today).inDays;
          final diffB = dateB.difference(today).inDays;
          
          // Prioritize games happening today or in the future
          if (diffA >= 0 && diffB < 0) return -1; // A is today/future, B is past
          if (diffA < 0 && diffB >= 0) return 1;  // A is past, B is today/future
          
          // If both are in the same category (past or future/today), sort by proximity
          final absDiffA = diffA.abs();
          final absDiffB = diffB.abs();
          
          if (absDiffA == absDiffB) {
            // If equidistant, prioritize future games over past games
            return diffA.compareTo(diffB);
          }
          
          return absDiffA.compareTo(absDiffB);
        });
        
    if (availableGames.isNotEmpty && _selectedGame == null) {
      _selectedGame = availableGames.first;
    } else if (availableGames.isEmpty) {
      _selectedGame = null;
    }
    // If a game was selected, ensure it's still in the list
    if (_selectedGame != null && !availableGames.any((game) => game.id == _selectedGame!.id)) {
        _selectedGame = availableGames.isNotEmpty ? availableGames.first : null;
    }
  }
  
  // Retry sync method for when sync fails
  Future<void> _retrySync() async {
    if (!mounted) return;
    setState(() {
      _isPerformingAsyncOperation = true;
      _errorMessage = null;
    });

    final syncResult = await main_logic.attemptInitialDataSyncIfSignedIn();
    if (!mounted) return;
    
    _loadGamesInternal(); // Refresh game list from Hive

    if (syncResult['status'] == 'sync_success') {
      setState(() {
        _screenState = availableGames.isEmpty ? _ScreenState.noGamesFound : _ScreenState.dataLoaded;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = syncResult['message'] as String?;
        _screenState = availableGames.isEmpty ? _ScreenState.noGamesFound : _ScreenState.syncFailed;
      });
    }
    
    if (mounted) {
      setState(() {
        _isPerformingAsyncOperation = false;
      });
    }
  }


  // Function to handle game selection and navigation
  void _selectGameAndNavigate() {
    if (_selectedGame != null) {
      // Show attendance dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AttendanceDialog(
            gameId: _selectedGame!.id,
            teamId: widget.teamId,
            onComplete: () {
              // After attendance is saved, navigate to stats screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LogStatsScreen(
                    gameId: _selectedGame!.id,
                    teamId: widget.teamId,
                  ),
                ),
              );
            },
          );
        },
      );
    } else {
      // Show a message if no game is available or selected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a game.')), // const added
      );
    }
  }

  // Show dialog to add a new game
  void _showAddGameDialog(BuildContext context) {
    // Controllers for form fields
    final TextEditingController opponentController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    
    DateTime selectedDate = DateTime.now(); // Initial date

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Renamed context to avoid conflict
        return StatefulBuilder( // Added StatefulBuilder
          builder: (BuildContext context, StateSetter setStateDialog) { // Renamed context and added setStateDialog
            // Show date picker
            Future<void> selectDateInDialog() async { // Renamed and adapted _selectDate
              final DateTime? picked = await showDatePicker(
                context: context, // Use StatefulBuilder's context
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null && picked != selectedDate) {
                setStateDialog(() { // Use setState from StatefulBuilder
                  selectedDate = picked;
                });
              }
            }

            return AlertDialog(
              title: const Text('Add New Game'), // const added
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    ListTile(
                      title: const Text('Game Date'), // const added
                      subtitle: Text(selectedDate.toLocal().toString().split(' ')[0]),
                      trailing: const Icon(Icons.calendar_today), // const added
                      onTap: selectDateInDialog, // Use the new method
                    ),
                    const SizedBox(height: 16),
                    
                // Opponent field
                TextField(
                  controller: opponentController,
                  decoration: const InputDecoration( // const added
                    labelText: 'Opponent',
                    hintText: 'Enter opponent team name',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location field
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration( // const added
                    labelText: 'Location (optional)',
                    hintText: 'Enter game location',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // Use dialogContext
              child: const Text('Cancel'), // const added
            ),
            TextButton(
              onPressed: () {
                _saveNewGame(
                  context, // This context should be the original _showAddGameDialog context
                  selectedDate,
                  opponentController.text,
                  locationController.text,
                );
                // Navigator.of(dialogContext).pop(); // Pop is handled in _saveNewGame on success
              },
              child: const Text('Save'), // const added
            ),
          ],
        );
          },
        );
      },
    );
  }
  
  // Show dialog to edit an existing game
  void _showEditGameDialog(BuildContext context, Game game) {
    // Controllers for form fields
    final TextEditingController opponentController = TextEditingController(text: game.opponent);
    final TextEditingController locationController = TextEditingController(text: game.location ?? '');
    
    DateTime selectedDate = game.date; // Initial date

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Renamed context
        return StatefulBuilder( // Added StatefulBuilder
          builder: (BuildContext context, StateSetter setStateDialog) { // Renamed context and added setStateDialog
            // Show date picker
            Future<void> selectDateInDialog() async { // Renamed and adapted _selectDate
              final DateTime? picked = await showDatePicker(
                context: context, // Use StatefulBuilder's context
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null && picked != selectedDate) {
                setStateDialog(() { // Use setState from StatefulBuilder
                  selectedDate = picked;
                });
              }
            }

            return AlertDialog(
              title: const Text('Edit Game'), // const added
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    ListTile(
                      title: const Text('Game Date'), // const added
                      subtitle: Text(selectedDate.toLocal().toString().split(' ')[0]),
                      trailing: const Icon(Icons.calendar_today), // const added
                      onTap: selectDateInDialog, // Use the new method
                    ),
                    const SizedBox(height: 16),
                    
                // Opponent field
                TextField(
                  controller: opponentController,
                  decoration: const InputDecoration( // const added
                    labelText: 'Opponent',
                    hintText: 'Enter opponent team name',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location field
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration( // const added
                    labelText: 'Location (optional)',
                    hintText: 'Enter game location',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // Use dialogContext
              child: const Text('Cancel'), // const added
            ),
            TextButton(
              onPressed: () {
                _updateGame(
                  context, // This context should be the original _showEditGameDialog context
                  game.id,
                  selectedDate,
                  opponentController.text,
                  locationController.text,
                );
                // Navigator.of(dialogContext).pop(); // Pop is handled in _updateGame on success
              },
              child: const Text('Save'), // const added
            ),
          ],
        );
          },
        );
      },
    );
  }
  
  // Show confirmation dialog to delete a game
  void _showDeleteGameDialog(BuildContext context, Game game) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Game'), // const added
          content: Text('Are you sure you want to delete the game on ${game.date.toLocal().toString().split(' ')[0]} ${game.opponent}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'), // const added
            ),
            TextButton(
              onPressed: () => _deleteGame(context, game.id),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'), // const added
            ),
          ],
        );
      },
    );
  }
  
  // Update an existing game in the local database and optionally sync to Google Sheets
  Future<void> _updateGame(
    BuildContext context,
    String gameId,
    DateTime date,
    String opponent,
    String location,
  ) async {
    // Validate input
    if (opponent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an opponent name')), // const added
      );
      return;
    }
    
    setState(() {
      _isPerformingAsyncOperation = true;
    });
    
    try {
      // Create an updated Game object with the current team ID
      final Game updatedGame = Game(
        id: gameId,
        date: date,
        opponent: opponent,
        location: location.isNotEmpty ? location : null,
        teamId: widget.teamId, // Set the team ID to the current team
      );
      
      // Update in local database
      await gamesBox.put(gameId, updatedGame);
      
      // Attempt to sync to Google Sheets if user is signed in
      bool syncedToSheets = false;
      if (await _sheetsService.isSignedIn()) {
        // TODO: Implement method in SheetsService to sync a single game
        // For now, we'll just call syncDataFromSheets() which syncs everything
        final result = await _sheetsService.syncDataFromSheets();
        syncedToSheets = result['success'] == true;
      }
      
      // Reload games list
      _loadGamesInternal();
      if (mounted) setState(() {}); // Update UI with new list
      
      // Close the dialog
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedToSheets
                ? 'Game updated and synced to Google Sheets'
                : 'Game updated locally',
          ),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating game: $e')),
      );
    } finally {
      setState(() {
        _isPerformingAsyncOperation = false;
      });
    }
  }
  
  // Delete a game from the local database
  Future<void> _deleteGame(BuildContext context, String gameId) async {
    setState(() {
      _isPerformingAsyncOperation = true;
    });
    
    try {
      // Delete from local database
      await gamesBox.delete(gameId);
      
      // Attempt to sync to Google Sheets if user is signed in
      bool syncedToSheets = false;
      if (await _sheetsService.isSignedIn()) {
        // TODO: Implement method in SheetsService to sync deletion
        // For now, we'll just call syncDataFromSheets() which syncs everything
        final result = await _sheetsService.syncDataFromSheets();
        syncedToSheets = result['success'] == true;
      }
      
      // Reload games list
      _loadGamesInternal();
      if (mounted) setState(() {}); // Update UI with new list
      
      // Close the dialog
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedToSheets
                ? 'Game deleted and synced to Google Sheets'
                : 'Game deleted locally',
          ),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting game: $e')),
      );
    } finally {
      setState(() {
        _isPerformingAsyncOperation = false;
      });
    }
  }
  
  // Save a new game to the local database and optionally sync to Google Sheets
  Future<void> _saveNewGame(
    BuildContext context,
    DateTime date,
    String opponent,
    String location,
  ) async {
    // Validate input
    if (opponent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an opponent name')), // const added
      );
      return;
    }
    
    setState(() {
      _isPerformingAsyncOperation = true;
    });
    
    try {
      // Generate a unique ID for the game
      final String gameId = const Uuid().v4();
      
      // Create a new Game object with the current team ID
      final Game newGame = Game(
        id: gameId,
        date: date,
        opponent: opponent,
        location: location.isNotEmpty ? location : null,
        teamId: widget.teamId, // Set the team ID to the current team
      );
      
      // Save to local database
      await gamesBox.put(gameId, newGame);
      
      // Attempt to sync to Google Sheets if user is signed in
      bool syncedToSheets = false;
      if (await _sheetsService.isSignedIn()) {
        // TODO: Implement method in SheetsService to sync a single game
        // For now, we'll just call syncDataFromSheets() which syncs everything
        final result = await _sheetsService.syncDataFromSheets();
        syncedToSheets = result['success'] == true;
      }
      
      // Reload games list
      _loadGamesInternal();
      if (mounted) setState(() {}); // Update UI with new list
      
      // Close the dialog
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedToSheets
                ? 'Game added and synced to Google Sheets'
                : 'Game added locally',
          ),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding game: $e')),
      );
    } finally {
      setState(() {
        _isPerformingAsyncOperation = false;
      });
    }
  }

  // Build the sync status indicator
  Widget _buildSyncIndicator() {
    return IconButton(
      icon: _screenState == _ScreenState.initialLoading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : _screenState == _ScreenState.syncFailed
              ? const Icon(Icons.sync_problem, color: Colors.orange)
              : const Icon(Icons.cloud_done, color: Colors.green),
      tooltip: _screenState == _ScreenState.initialLoading
          ? 'Syncing with Google Sheets...'
          : _screenState == _ScreenState.syncFailed
              ? 'Sync failed. Tap to retry.'
              : 'Data synced with Google Sheets',
      onPressed: _isPerformingAsyncOperation
          ? null
          : _screenState == _ScreenState.syncFailed
              ? _retrySync
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Switch Team button
          IconButton(
            icon: const Icon(Icons.switch_account),
            tooltip: 'Switch Team',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Switch Team'),
                    content: const Text('Do you want to switch to a different team? This will sign you out of the current team.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (widget.onSignOut != null) {
                            widget.onSignOut!();
                          }
                        },
                        child: const Text('Switch Team'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          StreamBuilder<int>(
            stream: Hive.box<GameEvent>('gameEvents')
                .watch()
                .map((_) => Hive.box<GameEvent>('gameEvents')
                    .values
                    .where((e) => !e.isSynced)
                    .length),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Badge(
                label: Text(count.toString()),
                isLabelVisible: count > 0,
                child: IconButton(
                  icon: Icon(Icons.cloud_sync),
                  onPressed: () async {
                    final result = await context.read<SheetsService>().syncPendingEvents();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['failed']! > 0 
                            ? 'Synced ${result['success']} events (${result['failed']} failed)'
                            : 'Successfully synced ${result['success']} events'),
                        action: result['failed']! > 0
                            ? SnackBarAction(
                                label: 'Retry',
                                onPressed: () => context.read<SheetsService>().syncPendingEvents(),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          _buildSyncIndicator(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_screenState) {
      case _ScreenState.initialLoading:
        return const Center(child: CircularProgressIndicator());
      case _ScreenState.syncFailed:
        // Show games if available, with an error message about sync
        return _buildGameListUI(headerMessage: _errorMessage ?? "Sync failed. Displaying local data.");
      case _ScreenState.noGamesFound:
        return _buildNoGamesUI();
      case _ScreenState.dataLoaded:
        return _buildGameListUI();
      default:
        return const Center(child: Text('Something went wrong.'));
    }
  }

  Widget _buildNoGamesUI() {
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_errorMessage ?? 'No games found.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text(
              'Data syncs automatically with Google Sheets in the background.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            // Consider adding a button to load dummy data if desired for testing
            // TextButton(onPressed: () { main_logic.addDummyDataIfNeeded(); _initializeScreen(); }, child: Text("Load Dummy Data (Dev)")),
          ],
        ),
      ),
    );
  }

  Widget _buildGameListUI({String? headerMessage}) {
    // This is the main UI for displaying the list of games, similar to the original build method's core.
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (headerMessage != null) ...[
              Text(headerMessage, style: TextStyle(color: _screenState == _ScreenState.syncFailed ? Colors.orange[700] : Colors.black, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10.0),
            ],
            const Text(
              'Choose a game to track stats for:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            if (_isPerformingAsyncOperation && _screenState != _ScreenState.initialLoading) // Show small loader near list if refreshing
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,)), const SizedBox(width: 8), const Text("Loading games...")]),
                ),
            if (availableGames.isEmpty && !_isPerformingAsyncOperation)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text('No games available. Add a game to get started.', textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableGames.length,
                itemBuilder: (BuildContext context, int index) {
                  final game = availableGames[index];
                  final gameTitle = '${game.date.toLocal().toString().split(' ')[0]} ${game.opponent}';
                  final isSelected = _selectedGame?.id == game.id;
                  
                  return Card(
                    elevation: isSelected ? 4 : 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                        width: isSelected ? 2.0 : 0.0,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected ? LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.05),
                            Theme.of(context).primaryColor.withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ) : null,
                      ),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                gameTitle,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Theme.of(context).primaryColor : null,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getGameTypeColor(game.gameType),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getGameTypeText(game.gameType),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: game.location != null ? Text('at ${game.location}') : null,
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedGame = game;
                          });
                          _selectGameAndNavigate(); // Navigate immediately
                        },
                        // trailing: Row( // Removed Edit and Delete buttons
                        //   mainAxisSize: MainAxisSize.min,
                        //   children: [
                        //     IconButton(
                        //       icon: const Icon(Icons.edit),
                        //       tooltip: 'Edit Game',
                        //       onPressed: _isPerformingAsyncOperation ? null : () => _showEditGameDialog(context, game),
                        //     ),
                        //     IconButton(
                        //       icon: const Icon(Icons.delete),
                        //       tooltip: 'Delete Game',
                        //       onPressed: _isPerformingAsyncOperation ? null : () => _showDeleteGameDialog(context, game),
                        //     ),
                        //   ],
                        // ),
                      ),
                    ),
                  );
                },
              ),
            // const SizedBox(height: 24.0), // Removed SizedBox for button
            // ElevatedButton( // Removed "Start Tracking" button
            //   onPressed: (_selectedGame == null || _isPerformingAsyncOperation) ? null : _selectGameAndNavigate,
            //   child: const Text('Start Tracking'),
            // ),
            // const SizedBox(height: 16.0), // Removed SizedBox
            // OutlinedButton( // Removed "Add New Game" button
            //   onPressed: _isPerformingAsyncOperation ? null : () => _showAddGameDialog(context),
            //   child: const Text('Add New Game'),
            // ),
          ],
        ),
      ),
    );
  }
}
