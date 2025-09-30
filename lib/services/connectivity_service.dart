import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Enum for connection quality levels
enum ConnectionQuality {
  offline,
  poor,
  good,
  unknown,
}

/// Service for managing connectivity status and providing quick offline detection
/// This service runs connectivity checks in the background to avoid blocking the UI
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  Timer? _periodicTimer;
  
  // Current connectivity state
  bool _isOnline = true;
  bool _canReachGoogleAPIs = false;
  DateTime? _lastConnectivityCheck;
  
  // Cache connectivity status for quick access
  static const Duration _cacheValidDuration = Duration(seconds: 30);
  static const Duration _quickCheckTimeout = Duration(seconds: 2);
  
  // Stream controller for connectivity changes
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  
  /// Stream of connectivity status changes
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  /// Quick check if device is online (uses cached result if recent)
  bool get isOnline => _isOnline;
  
  /// Quick check if Google APIs are reachable (uses cached result if recent)
  bool get canReachGoogleAPIs => _canReachGoogleAPIs;
  
  /// Initialize the connectivity service
  Future<void> initialize() async {
    print('ConnectivityService: Initializing...');
    
    // Perform initial connectivity check
    await _performConnectivityCheck();
    
    // Schedule periodic background checks
    _schedulePeriodicChecks();
    
    print('ConnectivityService: Initialized. Online: $_isOnline, Google APIs: $_canReachGoogleAPIs');
  }
  
  /// Dispose of the service
  void dispose() {
    _periodicTimer?.cancel();
    _connectivityController.close();
  }
  
  /// Schedule a quick connectivity check
  void _scheduleQuickCheck() {
    Timer(const Duration(milliseconds: 500), () {
      _performConnectivityCheck();
    });
  }
  
  /// Schedule periodic background connectivity checks
  void _schedulePeriodicChecks() {
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_shouldPerformCheck()) {
        _performConnectivityCheck();
      }
    });
  }
  
  /// Check if we should perform a connectivity check
  bool _shouldPerformCheck() {
    if (_lastConnectivityCheck == null) return true;
    return DateTime.now().difference(_lastConnectivityCheck!) > _cacheValidDuration;
  }
  
  /// Perform actual connectivity check in background
  Future<void> _performConnectivityCheck() async {
    try {
      print('ConnectivityService: Performing connectivity check...');
      
      // Quick internet check with short timeout
      final hasInternet = await _quickInternetCheck();
      
      bool canReachGoogle = false;
      if (hasInternet) {
        // Only check Google APIs if we have basic internet
        canReachGoogle = await _quickGoogleAPICheck();
      }
      
      _updateConnectivityStatus(hasInternet, canReachGoogle);
      _lastConnectivityCheck = DateTime.now();
      
      print('ConnectivityService: Check complete. Internet: $hasInternet, Google APIs: $canReachGoogle');
    } catch (e) {
      print('ConnectivityService: Error during connectivity check: $e');
      // On error, assume offline to be safe
      _updateConnectivityStatus(false, false);
    }
  }
  
  /// Quick internet connectivity check with short timeout
  Future<bool> _quickInternetCheck() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(_quickCheckTimeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      print('ConnectivityService: Quick internet check failed: $e');
      return false;
    }
  }
  
  /// Quick Google APIs connectivity check with short timeout
  Future<bool> _quickGoogleAPICheck() async {
    try {
      final response = await http.head(
        Uri.parse('https://oauth2.googleapis.com'),
      ).timeout(_quickCheckTimeout);
      
      return response.statusCode < 500;
    } catch (e) {
      print('ConnectivityService: Quick Google APIs check failed: $e');
      return false;
    }
  }
  
  /// Update connectivity status and notify listeners
  void _updateConnectivityStatus(bool isOnline, bool canReachGoogle) {
    final wasOnline = _isOnline;
    _isOnline = isOnline;
    _canReachGoogleAPIs = canReachGoogle;
    
    // Notify listeners if status changed
    if (wasOnline != isOnline) {
      _connectivityController.add(isOnline);
      print('ConnectivityService: Status changed - Online: $isOnline');
    }
  }
  
  /// Force a connectivity check (non-blocking)
  void forceCheck() {
    print('ConnectivityService: Force check requested');
    _performConnectivityCheck();
  }
  
  /// Get detailed connectivity status
  Map<String, dynamic> getDetailedStatus() {
    return {
      'isOnline': _isOnline,
      'canReachGoogleAPIs': _canReachGoogleAPIs,
      'lastCheck': _lastConnectivityCheck?.toIso8601String(),
      'cacheAge': _lastConnectivityCheck != null 
          ? DateTime.now().difference(_lastConnectivityCheck!).inSeconds 
          : null,
    };
  }
  
  /// Check if we should attempt network operations
  bool shouldAttemptNetworkOperation() {
    return _isOnline && _canReachGoogleAPIs;
  }
  
  /// Check if we should attempt any network operation (even basic internet)
  bool shouldAttemptBasicNetworkOperation() {
    return _isOnline;
  }
  
  /// Lightweight check for UI operations - only uses cached status
  bool shouldAttemptNetworkOperationQuick() {
    // Only use cached results, no network calls
    return _isOnline && _canReachGoogleAPIs;
  }
  
  /// Get connection quality based on recent checks
  ConnectionQuality getConnectionQuality() {
    if (!_isOnline) {
      return ConnectionQuality.offline;
    }
    
    if (!_canReachGoogleAPIs) {
      return ConnectionQuality.poor;
    }
    
    // Check how recent our last connectivity check was
    if (_lastConnectivityCheck != null) {
      final age = DateTime.now().difference(_lastConnectivityCheck!);
      if (age > const Duration(minutes: 2)) {
        return ConnectionQuality.unknown;
      }
    }
    
    return ConnectionQuality.good;
  }
}
