import 'dart:io';
import 'package:http/http.dart' as http;

/// Utility class for network connectivity detection and handling
class NetworkUtils {
  static const Duration _timeout = Duration(seconds: 10);
  
  /// Check if the device has internet connectivity
  /// This performs a simple DNS lookup to Google's public DNS
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(_timeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      print('Internet connectivity check failed: $e');
      return false;
    }
  }
  
  /// Check if Google APIs are accessible
  /// This specifically tests connectivity to Google's OAuth servers
  static Future<bool> canReachGoogleAPIs() async {
    try {
      final response = await http.head(
        Uri.parse('https://oauth2.googleapis.com'),
      ).timeout(_timeout);
      
      return response.statusCode < 500; // Any response < 500 means we can reach the server
    } catch (e) {
      print('Google APIs connectivity check failed: $e');
      return false;
    }
  }
  
  /// Perform a comprehensive network connectivity check
  /// Returns a map with detailed connectivity information
  static Future<Map<String, dynamic>> performConnectivityCheck() async {
    print('Performing comprehensive network connectivity check...');
    
    final results = <String, dynamic>{
      'hasInternet': false,
      'canReachGoogle': false,
      'canReachGoogleAPIs': false,
      'timestamp': DateTime.now().toIso8601String(),
      'errors': <String>[],
    };
    
    // Check basic internet connectivity
    try {
      results['hasInternet'] = await hasInternetConnection();
      if (results['hasInternet']) {
        print('✓ Basic internet connectivity: Available');
      } else {
        print('✗ Basic internet connectivity: Not available');
        results['errors'].add('No basic internet connectivity');
      }
    } catch (e) {
      print('✗ Basic internet connectivity check failed: $e');
      results['errors'].add('Internet check failed: $e');
    }
    
    // Check Google connectivity
    if (results['hasInternet']) {
      try {
        final googleResult = await InternetAddress.lookup('google.com')
            .timeout(_timeout);
        results['canReachGoogle'] = googleResult.isNotEmpty;
        if (results['canReachGoogle']) {
          print('✓ Google.com reachable: Yes');
        } else {
          print('✗ Google.com reachable: No');
          results['errors'].add('Cannot reach google.com');
        }
      } catch (e) {
        print('✗ Google.com connectivity check failed: $e');
        results['errors'].add('Google connectivity check failed: $e');
      }
      
      // Check Google APIs connectivity
      try {
        results['canReachGoogleAPIs'] = await canReachGoogleAPIs();
        if (results['canReachGoogleAPIs']) {
          print('✓ Google APIs reachable: Yes');
        } else {
          print('✗ Google APIs reachable: No');
          results['errors'].add('Cannot reach Google OAuth APIs');
        }
      } catch (e) {
        print('✗ Google APIs connectivity check failed: $e');
        results['errors'].add('Google APIs check failed: $e');
      }
    }
    
    // Summary
    if (results['hasInternet'] && results['canReachGoogle'] && results['canReachGoogleAPIs']) {
      print('✓ Network connectivity: All checks passed');
      results['status'] = 'connected';
    } else if (results['hasInternet']) {
      print('⚠ Network connectivity: Partial connectivity (Google services may be blocked)');
      results['status'] = 'partial';
    } else {
      print('✗ Network connectivity: No internet connection');
      results['status'] = 'disconnected';
    }
    
    return results;
  }
  
  /// Get a user-friendly network status message
  static String getNetworkStatusMessage(Map<String, dynamic> connectivityResults) {
    final status = connectivityResults['status'] as String?;
    final errors = connectivityResults['errors'] as List<String>? ?? [];
    
    switch (status) {
      case 'connected':
        return 'Network connection is working properly.';
      case 'partial':
        return 'Internet connection available, but Google services may be blocked or restricted.';
      case 'disconnected':
        return 'No internet connection detected. The app will work in offline mode.';
      default:
        if (errors.isNotEmpty) {
          return 'Network connectivity issues detected: ${errors.first}';
        }
        return 'Unknown network status.';
    }
  }
  
  /// Check if the network error is likely due to connectivity issues
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Common network error patterns
    final networkErrorPatterns = [
      'socketexception',
      'failed host lookup',
      'no address associated with hostname',
      'network is unreachable',
      'connection refused',
      'connection timed out',
      'timeout',
      'no route to host',
      'dns resolution failed',
    ];
    
    return networkErrorPatterns.any((pattern) => errorString.contains(pattern));
  }
  
  /// Get a user-friendly error message for network errors
  static String getNetworkErrorMessage(dynamic error) {
    if (!isNetworkError(error)) {
      return error.toString();
    }
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('failed host lookup') || 
        errorString.contains('no address associated with hostname')) {
      return 'DNS resolution failed. Check your internet connection or DNS settings.';
    } else if (errorString.contains('connection refused')) {
      return 'Connection refused by server. The service may be temporarily unavailable.';
    } else if (errorString.contains('timeout')) {
      return 'Connection timed out. Check your internet connection.';
    } else if (errorString.contains('network is unreachable')) {
      return 'Network is unreachable. Check your internet connection.';
    } else {
      return 'Network connectivity issue detected. The app will work in offline mode.';
    }
  }
}
