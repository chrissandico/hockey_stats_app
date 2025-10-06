import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hockey_stats_app/utils/network_utils.dart';

/// Categories of sync errors
enum SyncErrorCategory {
  network,
  authentication,
  apiLimits,
  permissions,
  serverError,
  dataValidation,
  unknown
}

/// Detailed sync error information
class SyncErrorInfo {
  final SyncErrorCategory category;
  final String userMessage;
  final String technicalMessage;
  final String? suggestedAction;
  final bool isRetryable;
  
  const SyncErrorInfo({
    required this.category,
    required this.userMessage,
    required this.technicalMessage,
    this.suggestedAction,
    required this.isRetryable,
  });
}

/// Utility class for categorizing and providing descriptive error messages for sync failures
class SyncErrorUtils {
  
  /// Analyze an error and return detailed error information
  static SyncErrorInfo analyzeError(dynamic error, {http.Response? response}) {
    // Network connectivity errors
    if (NetworkUtils.isNetworkError(error)) {
      return _createNetworkError(error);
    }
    
    // HTTP response errors
    if (response != null) {
      return _analyzeHttpResponse(response, error);
    }
    
    // Authentication errors
    if (_isAuthenticationError(error)) {
      return _createAuthenticationError(error);
    }
    
    // Data validation errors
    if (_isDataValidationError(error)) {
      return _createDataValidationError(error);
    }
    
    // Generic error
    return _createUnknownError(error);
  }
  
  /// Create network error information
  static SyncErrorInfo _createNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('failed host lookup') || 
        errorString.contains('no address associated with hostname')) {
      return const SyncErrorInfo(
        category: SyncErrorCategory.network,
        userMessage: 'Cannot connect to Google Sheets - DNS resolution failed',
        technicalMessage: 'DNS lookup failed for Google services',
        suggestedAction: 'Check your internet connection and DNS settings. Try switching to mobile data or a different WiFi network.',
        isRetryable: true,
      );
    }
    
    if (errorString.contains('connection refused')) {
      return const SyncErrorInfo(
        category: SyncErrorCategory.network,
        userMessage: 'Google Sheets service is temporarily unavailable',
        technicalMessage: 'Connection refused by Google servers',
        suggestedAction: 'Google services may be experiencing issues. Try again in a few minutes.',
        isRetryable: true,
      );
    }
    
    if (errorString.contains('timeout')) {
      return const SyncErrorInfo(
        category: SyncErrorCategory.network,
        userMessage: 'Connection to Google Sheets timed out',
        technicalMessage: 'Network request timed out',
        suggestedAction: 'Your connection may be slow or unstable. Try moving to an area with better signal or switching networks.',
        isRetryable: true,
      );
    }
    
    if (errorString.contains('network is unreachable')) {
      return const SyncErrorInfo(
        category: SyncErrorCategory.network,
        userMessage: 'No internet connection available',
        technicalMessage: 'Network is unreachable',
        suggestedAction: 'Check your WiFi or mobile data connection and try again.',
        isRetryable: true,
      );
    }
    
    // Generic network error
    return SyncErrorInfo(
      category: SyncErrorCategory.network,
      userMessage: 'Network connection issue preventing sync',
      technicalMessage: 'Network error: ${error.toString()}',
      suggestedAction: 'Check your internet connection and try again.',
      isRetryable: true,
    );
  }
  
  /// Analyze HTTP response errors
  static SyncErrorInfo _analyzeHttpResponse(http.Response response, dynamic error) {
    final statusCode = response.statusCode;
    final responseBody = response.body;
    
    switch (statusCode) {
      case 401:
        return const SyncErrorInfo(
          category: SyncErrorCategory.authentication,
          userMessage: 'Authentication failed - service account credentials invalid',
          technicalMessage: 'HTTP 401 Unauthorized',
          suggestedAction: 'Contact your administrator to check the service account configuration.',
          isRetryable: false,
        );
        
      case 403:
        if (responseBody.contains('PERMISSION_DENIED') || responseBody.contains('insufficient permissions')) {
          return const SyncErrorInfo(
            category: SyncErrorCategory.permissions,
            userMessage: 'No permission to access Google Sheets',
            technicalMessage: 'HTTP 403 Forbidden - Insufficient permissions',
            suggestedAction: 'Make sure the service account email is added to the Google Sheet with Editor permissions.',
            isRetryable: false,
          );
        } else if (responseBody.contains('RATE_LIMIT_EXCEEDED') || responseBody.contains('quota')) {
          return const SyncErrorInfo(
            category: SyncErrorCategory.apiLimits,
            userMessage: 'Google Sheets API rate limit exceeded',
            technicalMessage: 'HTTP 403 Forbidden - Rate limit exceeded',
            suggestedAction: 'Too many requests sent to Google Sheets. Wait a few minutes before trying again.',
            isRetryable: true,
          );
        } else {
          return const SyncErrorInfo(
            category: SyncErrorCategory.permissions,
            userMessage: 'Access denied to Google Sheets',
            technicalMessage: 'HTTP 403 Forbidden',
            suggestedAction: 'Check that the service account has proper permissions to access the spreadsheet.',
            isRetryable: false,
          );
        }
        
      case 404:
        if (responseBody.contains('spreadsheet') || responseBody.contains('Requested entity was not found')) {
          return const SyncErrorInfo(
            category: SyncErrorCategory.permissions,
            userMessage: 'Google Sheet not found or not accessible',
            technicalMessage: 'HTTP 404 Not Found - Spreadsheet not found',
            suggestedAction: 'Verify the spreadsheet ID is correct and the service account has access to it.',
            isRetryable: false,
          );
        } else {
          return const SyncErrorInfo(
            category: SyncErrorCategory.serverError,
            userMessage: 'Google Sheets endpoint not found',
            technicalMessage: 'HTTP 404 Not Found',
            suggestedAction: 'This may be a temporary Google Sheets service issue. Try again later.',
            isRetryable: true,
          );
        }
        
      case 429:
        return const SyncErrorInfo(
          category: SyncErrorCategory.apiLimits,
          userMessage: 'Too many requests to Google Sheets',
          technicalMessage: 'HTTP 429 Too Many Requests',
          suggestedAction: 'Slow down sync requests. The app will automatically retry with delays.',
          isRetryable: true,
        );
        
      case 500:
      case 502:
      case 503:
      case 504:
        return SyncErrorInfo(
          category: SyncErrorCategory.serverError,
          userMessage: 'Google Sheets service is temporarily unavailable',
          technicalMessage: 'HTTP $statusCode Server Error',
          suggestedAction: 'Google Sheets is experiencing issues. Your data is saved locally and will sync when the service recovers.',
          isRetryable: true,
        );
        
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return SyncErrorInfo(
            category: SyncErrorCategory.dataValidation,
            userMessage: 'Invalid data sent to Google Sheets',
            technicalMessage: 'HTTP $statusCode Client Error',
            suggestedAction: 'There may be an issue with the data format. Contact support if this persists.',
            isRetryable: false,
          );
        } else {
          return SyncErrorInfo(
            category: SyncErrorCategory.serverError,
            userMessage: 'Unexpected response from Google Sheets',
            technicalMessage: 'HTTP $statusCode',
            suggestedAction: 'Try again later. Contact support if the issue persists.',
            isRetryable: true,
          );
        }
    }
  }
  
  /// Check if error is authentication-related
  static bool _isAuthenticationError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('authentication') ||
           errorString.contains('unauthorized') ||
           errorString.contains('invalid_grant') ||
           errorString.contains('access_denied') ||
           errorString.contains('token');
  }
  
  /// Create authentication error information
  static SyncErrorInfo _createAuthenticationError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('invalid_grant')) {
      return const SyncErrorInfo(
        category: SyncErrorCategory.authentication,
        userMessage: 'Service account credentials have expired or are invalid',
        technicalMessage: 'OAuth invalid_grant error',
        suggestedAction: 'Contact your administrator to refresh the service account credentials.',
        isRetryable: false,
      );
    }
    
    if (errorString.contains('access_denied')) {
      return const SyncErrorInfo(
        category: SyncErrorCategory.authentication,
        userMessage: 'Access denied by Google authentication service',
        technicalMessage: 'OAuth access_denied error',
        suggestedAction: 'Check that the service account is properly configured and enabled.',
        isRetryable: false,
      );
    }
    
    return SyncErrorInfo(
      category: SyncErrorCategory.authentication,
      userMessage: 'Authentication failed with Google Sheets',
      technicalMessage: 'Authentication error: ${error.toString()}',
      suggestedAction: 'Contact your administrator to check the service account setup.',
      isRetryable: false,
    );
  }
  
  /// Check if error is data validation-related
  static bool _isDataValidationError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('invalid') ||
           errorString.contains('malformed') ||
           errorString.contains('bad request') ||
           errorString.contains('validation');
  }
  
  /// Create data validation error information
  static SyncErrorInfo _createDataValidationError(dynamic error) {
    return SyncErrorInfo(
      category: SyncErrorCategory.dataValidation,
      userMessage: 'Data format issue preventing sync',
      technicalMessage: 'Data validation error: ${error.toString()}',
      suggestedAction: 'This is likely a temporary issue. If it persists, contact support.',
      isRetryable: false,
    );
  }
  
  /// Create unknown error information
  static SyncErrorInfo _createUnknownError(dynamic error) {
    return SyncErrorInfo(
      category: SyncErrorCategory.unknown,
      userMessage: 'Unexpected error occurred during sync',
      technicalMessage: 'Unknown error: ${error.toString()}',
      suggestedAction: 'Try again later. Contact support if the issue persists.',
      isRetryable: true,
    );
  }
  
  /// Get a short status message for the sync error category
  static String getCategoryStatusMessage(SyncErrorCategory category) {
    switch (category) {
      case SyncErrorCategory.network:
        return 'Network Issue';
      case SyncErrorCategory.authentication:
        return 'Authentication Failed';
      case SyncErrorCategory.apiLimits:
        return 'Rate Limited';
      case SyncErrorCategory.permissions:
        return 'Access Denied';
      case SyncErrorCategory.serverError:
        return 'Server Error';
      case SyncErrorCategory.dataValidation:
        return 'Data Error';
      case SyncErrorCategory.unknown:
        return 'Sync Error';
    }
  }
  
  /// Get an icon name for the error category (for UI display)
  static String getCategoryIcon(SyncErrorCategory category) {
    switch (category) {
      case SyncErrorCategory.network:
        return 'wifi_off';
      case SyncErrorCategory.authentication:
        return 'lock';
      case SyncErrorCategory.apiLimits:
        return 'hourglass_empty';
      case SyncErrorCategory.permissions:
        return 'block';
      case SyncErrorCategory.serverError:
        return 'error';
      case SyncErrorCategory.dataValidation:
        return 'warning';
      case SyncErrorCategory.unknown:
        return 'help';
    }
  }
  
  /// Determine if multiple errors of the same category should be grouped
  static bool shouldGroupErrors(SyncErrorCategory category) {
    switch (category) {
      case SyncErrorCategory.network:
      case SyncErrorCategory.apiLimits:
      case SyncErrorCategory.serverError:
        return true; // These can be grouped as they're often temporary
      case SyncErrorCategory.authentication:
      case SyncErrorCategory.permissions:
      case SyncErrorCategory.dataValidation:
      case SyncErrorCategory.unknown:
        return false; // These should be shown individually
    }
  }
}
