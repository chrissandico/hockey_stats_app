import 'package:hive_flutter/hive_flutter.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';

/// Test script to manually sync attendance data for games id=6 and id=7
/// This script will check for locally stored attendance data and sync it to Google Sheets
Future<void> main() async {
  print('Starting attendance sync test for games id=6 and id=7...');
  
  try {
    // Initialize Hive
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(PlayerAdapter());
    Hive.registerAdapter(GameAdapter());
    Hive.registerAdapter(GameEventAdapter());
    Hive.registerAdapter(GameRosterAdapter());
    Hive.registerAdapter(GameAttendanceAdapter());
    Hive.registerAdapter(SyncPreferencesAdapter());
    Hive.registerAdapter(GoalSituationAdapter());
    Hive.registerAdapter(EmailSettingsAdapter());
    
    // Open boxes
    await Hive.openBox<Player>('players');
    await Hive.openBox<Game>('games');
    await Hive.openBox<GameEvent>('gameEvents');
    await Hive.openBox<GameRoster>('gameRoster');
    await Hive.openBox<GameAttendance>('gameAttendance');
    await Hive.openBox<SyncPreferences>('syncPreferences');
    await Hive.openBox<EmailSettings>('emailSettings');
    
    print('Hive initialized successfully');
    
    // Check for attendance data for games 6 and 7
    final attendanceBox = Hive.box<GameAttendance>('gameAttendance');
    final allAttendance = attendanceBox.values.toList();
    
    print('Found ${allAttendance.length} total attendance records');
    
    // Filter for games 6 and 7
    final targetGames = ['6', '7'];
    final targetAttendance = allAttendance.where((attendance) => 
        targetGames.contains(attendance.gameId)).toList();
    
    print('Found ${targetAttendance.length} attendance records for games 6 and 7:');
    for (final attendance in targetAttendance) {
      print('  Game ${attendance.gameId}: ${attendance.absentPlayerIds.length} absent players, synced: ${attendance.isSynced}');
    }
    
    if (targetAttendance.isEmpty) {
      print('No attendance data found for games 6 and 7');
      print('Checking if games exist...');
      
      final gamesBox = Hive.box<Game>('games');
      final game6 = gamesBox.get('6');
      final game7 = gamesBox.get('7');
      
      print('Game 6 exists: ${game6 != null}');
      print('Game 7 exists: ${game7 != null}');
      
      if (game6 != null) {
        print('Game 6: ${game6.opponent} on ${game6.date}');
      }
      if (game7 != null) {
        print('Game 7: ${game7.opponent} on ${game7.date}');
      }
      
      return;
    }
    
    // Initialize SheetsService and sync the attendance
    final sheetsService = SheetsService();
    
    print('Checking authentication...');
    final isAuthenticated = await sheetsService.isSignedIn();
    if (!isAuthenticated) {
      print('ERROR: Not authenticated with Google Sheets');
      return;
    }
    print('Authentication successful');
    
    // Sync each attendance record
    int successCount = 0;
    int failureCount = 0;
    
    for (final attendance in targetAttendance) {
      print('\nSyncing attendance for game ${attendance.gameId}...');
      
      try {
        final success = await sheetsService.syncGameAttendance(attendance);
        if (success) {
          successCount++;
          print('✓ Successfully synced attendance for game ${attendance.gameId}');
        } else {
          failureCount++;
          print('✗ Failed to sync attendance for game ${attendance.gameId}');
        }
      } catch (e) {
        failureCount++;
        print('✗ Error syncing attendance for game ${attendance.gameId}: $e');
      }
    }
    
    print('\n=== SYNC RESULTS ===');
    print('Successfully synced: $successCount');
    print('Failed to sync: $failureCount');
    print('Total processed: ${successCount + failureCount}');
    
    // Check final sync status
    print('\n=== FINAL STATUS ===');
    final finalAttendance = attendanceBox.values.where((attendance) => 
        targetGames.contains(attendance.gameId)).toList();
    
    for (final attendance in finalAttendance) {
      print('Game ${attendance.gameId}: synced = ${attendance.isSynced}');
    }
    
  } catch (e) {
    print('ERROR: $e');
  } finally {
    await Hive.close();
    print('Test completed');
  }
}
