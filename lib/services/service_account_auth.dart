import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Service for handling Google API authentication using a service account
class ServiceAccountAuth {
  static const String _serviceAccountPath = 'assets/config/service_account.json';
  static final List<String> _scopes = ['https://www.googleapis.com/auth/spreadsheets'];
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  
  static ServiceAccountAuth? _instance;
  Map<String, dynamic>? _serviceAccountData;
  http.Client? _client;
  String? _accessToken;
  DateTime? _tokenExpiry;
  
  /// Private constructor for singleton pattern
  ServiceAccountAuth._();
  
  /// Get the singleton instance of ServiceAccountAuth
  static Future<ServiceAccountAuth> get instance async {
    if (_instance == null) {
      // Only publish the singleton after a successful init: caching a
      // half-initialized instance (e.g. the app was started offline and
      // the first token fetch failed) would poison auth for the whole
      // process and only an app restart would clear it.
      final candidate = ServiceAccountAuth._();
      await candidate._initialize();
      _instance = candidate;
    }
    return _instance!;
  }

  /// How long before its expiry a token is treated as stale.
  static const Duration tokenRefreshSkew = Duration(minutes: 5);

  /// Whether a token should be (re)fetched: no token, no recorded
  /// expiry, or expiry inside the skew window. Pure and static so the
  /// policy is unit-testable without loading credentials.
  static bool shouldRefreshToken({
    required bool hasToken,
    required DateTime? expiry,
    required DateTime now,
  }) {
    if (!hasToken) return true;
    if (expiry == null) return true;
    return !now.isBefore(expiry.subtract(tokenRefreshSkew));
  }

  bool get _tokenNeedsRefresh => shouldRefreshToken(
        hasToken: _accessToken != null,
        expiry: _tokenExpiry,
        now: DateTime.now(),
      );

  /// Ensures a usable access token exists, refreshing it when it is
  /// missing or near expiry. Returns false instead of throwing so
  /// callers can treat it as an authentication check.
  Future<bool> ensureValidToken() async {
    try {
      if (_tokenNeedsRefresh) {
        await _refreshAccessToken();
      }
      return _accessToken != null;
    } catch (e) {
      print('ServiceAccountAuth: ensureValidToken failed: $e');
      return false;
    }
  }
  
  /// Initialize the service account credentials
  Future<void> _initialize() async {
    try {
      // Load the service account JSON file
      final String serviceAccountJson = await rootBundle.loadString(_serviceAccountPath);
      
      if (serviceAccountJson.isEmpty) {
        throw Exception('Service account file is empty: $_serviceAccountPath');
      }
      
      _serviceAccountData = json.decode(serviceAccountJson);
      
      if (_serviceAccountData == null || _serviceAccountData!.isEmpty) {
        throw Exception('Service account data is invalid or empty');
      }
      
      // Validate required fields
      final requiredFields = ['client_email', 'private_key', 'project_id'];
      for (final field in requiredFields) {
        if (_serviceAccountData![field] == null || _serviceAccountData![field].toString().isEmpty) {
          throw Exception('Missing required field in service account: $field');
        }
      }
      
      // Create a basic HTTP client
      _client = http.Client();
      
      // Get an access token
      await _refreshAccessToken();
      
      print('Service account authentication initialized successfully');
    } catch (e) {
      print('Error initializing service account authentication: $e');
      print('Service account path: $_serviceAccountPath');
      print('Make sure the service account JSON file exists and contains valid credentials');
      rethrow;
    }
  }
  
  /// Refresh the access token with network connectivity handling
  Future<void> _refreshAccessToken() async {
    try {
      if (_serviceAccountData == null) {
        throw Exception('Service account data not loaded');
      }
      
      // Create a JWT claim
      final now = DateTime.now();
      final expiry = now.add(const Duration(hours: 1));
      
      final Map<String, dynamic> claims = {
        'iss': _serviceAccountData!['client_email'],
        'scope': _scopes.join(' '),
        'aud': _tokenUrl,
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
      };
      
      // Create a JWT token
      final String jwt = _createJwt(claims);
      
      // Exchange JWT for access token with timeout and retry logic
      http.Response? response;
      int retryCount = 0;
      const int maxRetries = 3;
      const Duration timeout = Duration(seconds: 30);
      
      while (retryCount < maxRetries) {
        try {
          print('Attempting to obtain access token (attempt ${retryCount + 1}/$maxRetries)...');
          
          response = await http.post(
            Uri.parse(_tokenUrl),
            body: {
              'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
              'assertion': jwt,
            },
          ).timeout(timeout);
          
          break; // Success, exit retry loop
          
        } catch (e) {
          retryCount++;
          print('Network error on attempt $retryCount: $e');
          
          if (retryCount >= maxRetries) {
            print('Max retries reached. Network connectivity issue detected.');
            print('This is likely due to:');
            print('1. No internet connection');
            print('2. DNS resolution failure for oauth2.googleapis.com');
            print('3. Firewall blocking the connection');
            print('4. Network timeout');
            print('The app will continue to work offline.');
            rethrow;
          }
          
          // Exponential backoff: wait 2^retryCount seconds before retry
          final backoffDelay = Duration(seconds: (2 * retryCount).clamp(1, 10));
          print('Retrying in ${backoffDelay.inSeconds} seconds...');
          await Future.delayed(backoffDelay);
        }
      }
      
      if (response != null && response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        _accessToken = tokenData['access_token'];
        final expiresIn = tokenData['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        print('Successfully obtained access token, expires in $expiresIn seconds');
      } else if (response != null) {
        print('Failed to obtain access token: ${response.statusCode} - ${response.body}');
        _accessToken = null;
        _tokenExpiry = null;
        throw Exception('Failed to obtain access token: ${response.statusCode}');
      } else {
        print('No response received from OAuth server');
        _accessToken = null;
        _tokenExpiry = null;
        throw Exception('No response from OAuth server');
      }
    } catch (e) {
      print('Error refreshing access token: $e');
      _accessToken = null;
      _tokenExpiry = null;
      rethrow;
    }
  }
  
  /// Create a JWT token
  String _createJwt(Map<String, dynamic> claims) {
    try {
      // Get the private key from the service account JSON
      final privateKeyString = _serviceAccountData!['private_key'];
      
      // Create a JWT with the claims
      final jwt = JWT(claims);
      
      // Parse the private key and sign the JWT with RS256 algorithm
      final token = jwt.sign(
        RSAPrivateKey(privateKeyString),
        algorithm: JWTAlgorithm.RS256,
      );
      
      print('Successfully created JWT token');
      return token;
    } catch (e) {
      print('Error creating JWT token: $e');
      rethrow;
    }
  }
  
  /// Get an HTTP client for making API requests
  /// Note: This method is kept for backward compatibility, but it's recommended to use makeAuthenticatedRequest instead
  Future<http.Client> getClient() async {
    if (_client == null) {
      await _initialize();
    } else if (_tokenNeedsRefresh) {
      // Token is expired or will expire soon, refresh it
      print('Access token expired or will expire soon. Refreshing...');
      await _refreshAccessToken();
    }
    
    if (_client == null) {
      throw Exception('Failed to create HTTP client');
    }
    
    // Return the basic client - this is not recommended for direct use
    // Use makeAuthenticatedRequest instead which properly adds the authorization header
    print('Warning: Using getClient() directly is not recommended. Use makeAuthenticatedRequest() instead.');
    return _client!;
  }
  
  /// Make an authenticated request to the Google API
  Future<http.Response> makeAuthenticatedRequest(Uri url, {String method = 'GET', Map<String, String>? headers, Object? body}) async {
    // Refresh BEFORE the request when the token is missing or near
    // expiry. The previous behaviour — refreshing only when there was
    // no token at all — kept sending an expired token for the rest of
    // the process lifetime, so every Sheets request failed with 401
    // until the app was restarted.
    if (_tokenNeedsRefresh) {
      await _refreshAccessToken();
    }

    if (_accessToken == null) {
      throw Exception('Failed to obtain access token');
    }

    Future<http.Response> send() {
      // Add the authorization header with the access token
      final Map<String, String> authHeaders = {
        'Authorization': 'Bearer $_accessToken',
        ...?headers,
      };

      // Make the request with the authorization header
      switch (method) {
        case 'GET':
          return _client!.get(url, headers: authHeaders);
        case 'POST':
          return _client!.post(url, headers: authHeaders, body: body);
        case 'PUT':
          return _client!.put(url, headers: authHeaders, body: body);
        default:
          throw Exception('Unsupported method: $method');
      }
    }

    var response = await send();

    if (response.statusCode == 401) {
      // The token was rejected despite our records (revoked, invalidated
      // server-side, clock skew): fetch a fresh one and retry once.
      print('ServiceAccountAuth: Request rejected with 401, refreshing token and retrying once');
      await _refreshAccessToken();
      if (_accessToken == null) {
        throw Exception('Failed to obtain access token');
      }
      response = await send();
    }

    return response;
  }
  
  /// Get the current access token
  String? get accessToken => _accessToken;
  
  /// Check if the client is authenticated
  bool get isAuthenticated => _accessToken != null;
  
  /// Get the service account email
  String? get serviceAccountEmail => _serviceAccountData?['client_email'];
}
