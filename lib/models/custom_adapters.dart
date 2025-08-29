import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';

/// Custom adapter for Game class with migration support
class CustomGameAdapter extends TypeAdapter<Game> {
  @override
  final int typeId = 1; // Same typeId as the generated GameAdapter

  @override
  Game read(BinaryReader reader) {
    try {
      final numOfFields = reader.readByte();
      final fields = <int, dynamic>{
        for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
      };

      // Check if we have a version field (field 5)
      if (fields.containsKey(5)) {
        // This is a newer version with version field
        return Game(
          id: fields[0] as String,
          date: fields[1] as DateTime,
          opponent: fields[2] as String,
          location: fields[3] as String?,
          teamId: fields[4] as String,
          version: fields[5] as int,
        );
      } else {
        // This is an older version without version field and possibly without teamId
        // Use the migration factory constructor
        return Game.migrate(fields);
      }
    } catch (e) {
      print('Error reading Game from Hive: $e');
      // Fallback to a default Game object to prevent app crashes
      return Game(
        id: 'error_recovery_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        opponent: 'Unknown',
        teamId: 'your_team',
        version: 1,
      );
    }
  }

  @override
  void write(BinaryWriter writer, Game obj) {
    try {
      writer
        ..writeByte(6) // Now we have 6 fields including version
        ..writeByte(0)
        ..write(obj.id)
        ..writeByte(1)
        ..write(obj.date)
        ..writeByte(2)
        ..write(obj.opponent)
        ..writeByte(3)
        ..write(obj.location)
        ..writeByte(4)
        ..write(obj.teamId)
        ..writeByte(5)
        ..write(obj.version);
    } catch (e) {
      print('Error writing Game to Hive: $e');
      // We can't recover from write errors, but at least we log them
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomGameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

/// Migration manager for handling Hive database migrations
class HiveMigrationManager {
  /// Initialize migration manager and perform any needed migrations
  static Future<void> initialize() async {
    print('Initializing Hive Migration Manager...');
    
    // Register custom adapters that handle migrations
    _registerCustomAdapters();
    
    // Additional migration logic can be added here
    
    print('Hive Migration Manager initialized successfully');
  }
  
  /// Register all custom adapters that override the generated ones
  static void _registerCustomAdapters() {
    // Unregister the generated adapter if it's already registered
    try {
      if (Hive.isAdapterRegistered(1)) {
        print('Unregistering existing Game adapter');
        // Note: Hive doesn't provide a direct way to unregister adapters
        // This is a workaround that will be handled by our custom adapter
      }
    } catch (e) {
      print('Error checking adapter registration: $e');
    }
    
    // Register our custom adapter
    print('Registering custom Game adapter');
    Hive.registerAdapter(CustomGameAdapter());
  }
  
  /// Perform error recovery for corrupted boxes
  static Future<void> recoverCorruptedBox(String boxName) async {
    print('Attempting to recover corrupted box: $boxName');
    
    try {
      // Close the box if it's open
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      
      // Delete and recreate the box
      await Hive.deleteBoxFromDisk(boxName);
      await Hive.openBox(boxName);
      
      print('Successfully recovered box: $boxName');
    } catch (e) {
      print('Failed to recover box $boxName: $e');
      // If we can't recover, we'll have to let the app handle it
    }
  }
}
