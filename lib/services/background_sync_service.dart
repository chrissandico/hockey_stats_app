import 'dart:async';
import 'dart:isolate';
import 'package:hive/hive.dart';
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:hockey_stats_app/services/connectivity_service.dart';

/// Service for handling background synchronization of data with Google Sheets
/// This service runs sync operations in background isolates to avoid blocking the UI
class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  final SheetsService _sheetsService = SheetsService();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  
  // Batching system for efficient network operations
  final List<GameEvent> _pendingEventBatch = [];
  final List<GameRoster> _pendingRosterBatch = [];
  Timer? _batchTimer;
  static const Duration _batchDelay = Duration(seconds: 5);
  static const int _maxBatchSize = 10;
  
  // Stream controller for sync status updates
  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  
  /// Stream of sync status updates
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  
  /// Initialize the background sync service
  Future<void> initialize() async {
    print('BackgroundSyncService: Initializing...');
    
    // Start periodic sync every 5 minutes when online
    _schedulePeriodicSync();
    
    // Listen to connectivity changes to trigger sync when coming online
    _connectivityService.connectivityStream.listen((isOnline) {
      if (isOnline && !_isSyncing) {
        print('BackgroundSyncService: Device came online, triggering sync');
        _performBackgroundSync();
      }
    });
    
    print('BackgroundSyncService: Initialized');
  }
  
  /// Dispose of the service
  void dispose() {
    _periodicSyncTimer?.cancel();
    _syncStatusController.close();
  }
  
  /// Schedule periodic background sync
  void _schedulePeriodicSync() {
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_connectivityService.shouldAttemptNetworkOperation() && !_isSyncing) {
        _performBackgroundSync();
      }
    });
  }
  
  /// Perform background sync of all pending data
  Future<void> _performBackgroundSync() async {
    if (_isSyncing) {
      print('BackgroundSyncService: Sync already in progress, skipping');
      return;
    }
    
    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);
    
    try {
      print('BackgroundSyncService: Starting background sync...');
      
      // Sync pending events
      final eventResults = await _sheetsService.syncPendingEventsInBackground();
      print('BackgroundSyncService: Events sync - Success: ${eventResults['success']}, Failed: ${eventResults['failed']}');
      
      // Sync pending roster entries
      final rosterResults = await _sheetsService.syncPendingRosterInBackground();
      print('BackgroundSyncService: Roster sync - Success: ${rosterResults['success']}, Failed: ${rosterResults['failed']}');
      
      final totalSuccess = (eventResults['success'] ?? 0) + (rosterResults['success'] ?? 0);
      final totalFailed = (eventResults['failed'] ?? 0) + (rosterResults['failed'] ?? 0);
      
      if (totalFailed == 0 && totalSuccess > 0) {
        _syncStatusController.add(SyncStatus.success);
        print('BackgroundSyncService: All items synced successfully ($totalSuccess items)');
      } else if (totalSuccess > 0) {
        _syncStatusController.add(SyncStatus.partialSuccess);
        print('BackgroundSyncService: Partial sync success - $totalSuccess synced, $totalFailed failed');
      } else if (totalFailed > 0) {
        _syncStatusController.add(SyncStatus.failed);
        print('BackgroundSyncService: Sync failed - $totalFailed items failed');
      } else {
        _syncStatusController.add(SyncStatus.idle);
        print('BackgroundSyncService: No items to sync');
      }
      
    } catch (e) {
      print('BackgroundSyncService: Sync error: $e');
      _syncStatusController.add(SyncStatus.failed);
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Manually trigger a background sync
  Future<void> triggerSync() async {
    if (!_connectivityService.shouldAttemptNetworkOperation()) {
      print('BackgroundSyncService: Cannot sync - device is offline or Google APIs unreachable');
      _syncStatusController.add(SyncStatus.offline);
      return;
    }
    
    await _performBackgroundSync();
  }
  
  /// Get the current sync status
  SyncStatus getCurrentStatus() {
    if (!_connectivityService.isOnline) {
      return SyncStatus.offline;
    } else if (_isSyncing) {
      return SyncStatus.syncing;
    } else {
      return SyncStatus.idle;
    }
  }
  
  /// Check if there are pending items to sync
  Future<int> getPendingItemsCount() async {
    try {
      final gameEventsBox = Hive.box<GameEvent>('gameEvents');
      final gameRosterBox = Hive.box<GameRoster>('gameRoster');
      
      final pendingEvents = gameEventsBox.values.where((event) => !event.isSynced).length;
      final pendingRoster = gameRosterBox.values.where((roster) => !roster.isSynced).length;
      
      return pendingEvents + pendingRoster;
    } catch (e) {
      print('BackgroundSyncService: Error getting pending items count: $e');
      return 0;
    }
  }
  
  /// Queue an event for background sync with batching for better performance
  void queueEventForSync(GameEvent event, {Duration? delay}) {
    print('BackgroundSyncService: Queuing event ${event.id} for batched sync');
    
    // If online, add to batch for efficient processing
    if (_connectivityService.shouldAttemptNetworkOperation() && !_isSyncing) {
      _addEventToBatch(event);
    }
  }
  
  /// Add event to batch and schedule batch processing
  void _addEventToBatch(GameEvent event) {
    _pendingEventBatch.add(event);
    print('BackgroundSyncService: Added event ${event.id} to batch (${_pendingEventBatch.length}/$_maxBatchSize)');
    
    // Process batch immediately if it reaches max size
    if (_pendingEventBatch.length >= _maxBatchSize) {
      print('BackgroundSyncService: Batch size limit reached, processing immediately');
      _processBatch();
      return;
    }
    
    // Schedule batch processing if not already scheduled
    if (_batchTimer == null) {
      _batchTimer = Timer(_batchDelay, () {
        print('BackgroundSyncService: Batch timer expired, processing batch');
        _processBatch();
      });
    }
  }
  
  /// Process the current batch of events and roster entries
  Future<void> _processBatch() async {
    _batchTimer?.cancel();
    _batchTimer = null;
    
    if (_pendingEventBatch.isEmpty && _pendingRosterBatch.isEmpty) {
      return;
    }
    
    print('BackgroundSyncService: Processing batch - ${_pendingEventBatch.length} events, ${_pendingRosterBatch.length} roster entries');
    
    // Create copies and clear the pending batches
    final eventsToSync = List<GameEvent>.from(_pendingEventBatch);
    final rosterToSync = List<GameRoster>.from(_pendingRosterBatch);
    _pendingEventBatch.clear();
    _pendingRosterBatch.clear();
    
    // Process events batch
    if (eventsToSync.isNotEmpty) {
      await _syncEventsBatch(eventsToSync);
    }
    
    // Process roster batch
    if (rosterToSync.isNotEmpty) {
      await _syncRosterBatch(rosterToSync);
    }
  }
  
  /// Sync a batch of events efficiently
  Future<void> _syncEventsBatch(List<GameEvent> events) async {
    print('BackgroundSyncService: Syncing batch of ${events.length} events');
    
    int successCount = 0;
    int failureCount = 0;
    
    // Process events in smaller sub-batches to avoid overwhelming the API
    const subBatchSize = 5;
    for (int i = 0; i < events.length; i += subBatchSize) {
      final endIndex = (i + subBatchSize < events.length) ? i + subBatchSize : events.length;
      final subBatch = events.sublist(i, endIndex);
      
      // Process sub-batch concurrently
      final futures = subBatch.map((event) => _syncSingleEvent(event));
      final results = await Future.wait(futures.map((future) async {
        try {
          await future;
          return true;
        } catch (e) {
          print('BackgroundSyncService: Error in batch sync: $e');
          return false;
        }
      }));
      
      successCount += results.where((success) => success).length;
      failureCount += results.where((success) => !success).length;
      
      // Small delay between sub-batches to avoid rate limiting
      if (i + subBatchSize < events.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    print('BackgroundSyncService: Batch sync complete - $successCount successful, $failureCount failed');
  }
  
  /// Sync a batch of roster entries efficiently
  Future<void> _syncRosterBatch(List<GameRoster> rosterEntries) async {
    print('BackgroundSyncService: Syncing batch of ${rosterEntries.length} roster entries');
    
    int successCount = 0;
    int failureCount = 0;
    
    // Process roster entries concurrently
    final futures = rosterEntries.map((roster) => _syncSingleRoster(roster));
    final results = await Future.wait(futures.map((future) async {
      try {
        await future;
        return true;
      } catch (e) {
        print('BackgroundSyncService: Error in roster batch sync: $e');
        return false;
      }
    }));
    
    successCount = results.where((success) => success).length;
    failureCount = results.where((success) => !success).length;
    
    print('BackgroundSyncService: Roster batch sync complete - $successCount successful, $failureCount failed');
  }
  
  /// Queue a roster entry for background sync
  void queueRosterForSync(GameRoster roster) {
    print('BackgroundSyncService: Queuing roster entry ${roster.id} for sync');
    
    // If online, attempt immediate background sync
    if (_connectivityService.shouldAttemptNetworkOperation() && !_isSyncing) {
      Future.microtask(() => _syncSingleRoster(roster));
    }
  }
  
  /// Sync a single event in background
  Future<void> _syncSingleEvent(GameEvent event) async {
    try {
      final success = await _sheetsService.syncGameEvent(event);
      if (success) {
        print('BackgroundSyncService: Successfully synced event ${event.id}');
      } else {
        print('BackgroundSyncService: Failed to sync event ${event.id}');
      }
    } catch (e) {
      print('BackgroundSyncService: Error syncing event ${event.id}: $e');
    }
  }
  
  /// Sync a single roster entry in background
  Future<void> _syncSingleRoster(GameRoster roster) async {
    try {
      final success = await _sheetsService.syncGameRoster(roster);
      if (success) {
        print('BackgroundSyncService: Successfully synced roster ${roster.id}');
      } else {
        print('BackgroundSyncService: Failed to sync roster ${roster.id}');
      }
    } catch (e) {
      print('BackgroundSyncService: Error syncing roster ${roster.id}: $e');
    }
  }
}

/// Enum for sync status
enum SyncStatus {
  idle,
  syncing,
  success,
  partialSuccess,
  failed,
  offline,
}

/// Extension to get user-friendly sync status messages
extension SyncStatusExtension on SyncStatus {
  String get message {
    switch (this) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.syncing:
        return 'Syncing data...';
      case SyncStatus.success:
        return 'All data synced';
      case SyncStatus.partialSuccess:
        return 'Some data synced';
      case SyncStatus.failed:
        return 'Sync failed';
      case SyncStatus.offline:
        return 'Offline mode';
    }
  }
  
  bool get isError => this == SyncStatus.failed;
  bool get isSuccess => this == SyncStatus.success || this == SyncStatus.partialSuccess;
  bool get isActive => this == SyncStatus.syncing;
}
