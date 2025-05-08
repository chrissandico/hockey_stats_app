import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // Import Hive
import 'package:hockey_stats_app/models/data_models.dart'; // Import your data models
import 'package:hockey_stats_app/screens/log_stats_screen.dart'; // We'll create a new screen to hold the logging buttons
import 'package:hockey_stats_app/services/sheets_service.dart'; // Import SheetsService for syncing
import 'package:uuid/uuid.dart'; // Import for generating UUIDs

// This screen will allow the user to select a game from the local database.
class GameSelectionScreen extends StatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  _GameSelectionScreenState createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  // Hive Box for Games
  late Box<Game> gamesBox;
  List<Game> availableGames = [];
  Game? _selectedGame;
  
  // Service for syncing with Google Sheets
  final SheetsService _sheetsService = SheetsService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Get a reference to the Games box
    gamesBox = Hive.box<Game>('games');
    // Load games from the box
    _loadGames();
  }

  void _loadGames() {
    // Get all games from the box and convert to a list
    setState(() {
      availableGames = gamesBox.values.toList();
      // Optionally pre-select the first game if available
      if (availableGames.isNotEmpty) {
        _selectedGame = availableGames.first;
      }
    });
  }

  // Function to handle game selection and navigation
  void _selectGameAndNavigate() {
    if (_selectedGame != null) {
      // Navigate to a screen where stats can be logged for the selected game.
      // We'll create a new screen called LogStatsScreen which will contain
      // the "Log Shot" and "Log Penalty" buttons, passing the selected game ID.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LogStatsScreen(gameId: _selectedGame!.id),
        ),
      );
    } else {
      // Show a message if no game is available or selected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a game.')),
      );
    }
  }

  // Show dialog to add a new game
  void _showAddGameDialog(BuildContext context) {
    // Controllers for form fields
    final TextEditingController opponentController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    
    // Date picker state
    DateTime selectedDate = DateTime.now();
    
    // Show date picker
    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null && picked != selectedDate) {
        selectedDate = picked;
        // Force dialog to rebuild with new date
        Navigator.of(context).pop();
        _showAddGameDialog(context);
      }
    }
    
    // Show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Game'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                ListTile(
                  title: const Text('Game Date'),
                  subtitle: Text(selectedDate.toLocal().toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 16),
                
                // Opponent field
                TextField(
                  controller: opponentController,
                  decoration: const InputDecoration(
                    labelText: 'Opponent',
                    hintText: 'Enter opponent team name',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location field
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'Enter game location',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _saveNewGame(
                context,
                selectedDate,
                opponentController.text,
                locationController.text,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
  
  // Show dialog to edit an existing game
  void _showEditGameDialog(BuildContext context, Game game) {
    // Controllers for form fields
    final TextEditingController opponentController = TextEditingController(text: game.opponent);
    final TextEditingController locationController = TextEditingController(text: game.location ?? '');
    
    // Date picker state
    DateTime selectedDate = game.date;
    
    // Show date picker
    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null && picked != selectedDate) {
        selectedDate = picked;
        // Force dialog to rebuild with new date
        Navigator.of(context).pop();
        _showEditGameDialog(context, game.copyWith(date: selectedDate));
      }
    }
    
    // Show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Game'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                ListTile(
                  title: const Text('Game Date'),
                  subtitle: Text(selectedDate.toLocal().toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 16),
                
                // Opponent field
                TextField(
                  controller: opponentController,
                  decoration: const InputDecoration(
                    labelText: 'Opponent',
                    hintText: 'Enter opponent team name',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location field
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'Enter game location',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _updateGame(
                context,
                game.id,
                selectedDate,
                opponentController.text,
                locationController.text,
              ),
              child: const Text('Save'),
            ),
          ],
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
          title: const Text('Delete Game'),
          content: Text('Are you sure you want to delete the game on ${game.date.toLocal().toString().split(' ')[0]} vs ${game.opponent}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _deleteGame(context, game.id),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
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
        const SnackBar(content: Text('Please enter an opponent name')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Create an updated Game object
      final Game updatedGame = Game(
        id: gameId,
        date: date,
        opponent: opponent,
        location: location.isNotEmpty ? location : null,
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
      _loadGames();
      
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
        _isLoading = false;
      });
    }
  }
  
  // Delete a game from the local database
  Future<void> _deleteGame(BuildContext context, String gameId) async {
    setState(() {
      _isLoading = true;
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
      _loadGames();
      
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
        _isLoading = false;
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
        const SnackBar(content: Text('Please enter an opponent name')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Generate a unique ID for the game
      final String gameId = const Uuid().v4();
      
      // Create a new Game object
      final Game newGame = Game(
        id: gameId,
        date: date,
        opponent: opponent,
        location: location.isNotEmpty ? location : null,
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
      _loadGames();
      
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
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Game'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch elements horizontally
            children: <Widget>[
              const Text(
                'Choose a game to track stats for:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),

              // Games list with edit/delete options
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Games:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (availableGames.isEmpty)
                    const Text('No games available. Add a game to get started.', style: TextStyle(fontStyle: FontStyle.italic))
                  else
                    ...availableGames.map((game) {
                      // Format the game display
                      final gameTitle = '${game.date.toLocal().toString().split(' ')[0]} vs ${game.opponent}';
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
                            title: Text(
                              gameTitle,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Theme.of(context).primaryColor : null,
                              ),
                            ),
                            subtitle: game.location != null ? Text('at ${game.location}') : null,
                            selected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedGame = game;
                              });
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit Game',
                                  onPressed: () => _showEditGameDialog(context, game),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Delete Game',
                                  onPressed: () => _showDeleteGameDialog(context, game),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
              const SizedBox(height: 24.0),

              // Button to proceed after selecting a game
              ElevatedButton(
                onPressed: _selectGameAndNavigate,
                child: const Text('Start Tracking'),
              ),

              // Button to add a new game
              const SizedBox(height: 16.0),
              OutlinedButton(
                onPressed: () {
                  _showAddGameDialog(context);
                },
                child: const Text('Add New Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
