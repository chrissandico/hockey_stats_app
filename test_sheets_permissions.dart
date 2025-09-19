import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:io';

/// Simple diagnostic script to test Google Sheets permissions
/// Run with: dart test_sheets_permissions.dart
void main() async {
  print('🔍 Testing Google Sheets Permissions...\n');
  
  const String spreadsheetId = '1u4olfiYFjXW0Z88U3Q1wOxI7gz04KYbg6LNn8h-rfno';
  const String serviceAccountEmail = 'hockey-stats-service-new@hockey-stats-viewer.iam.gserviceaccount.com';
  
  try {
    // Load service account credentials
    final serviceAccountFile = File('assets/config/service_account.json');
    if (!serviceAccountFile.existsSync()) {
      print('❌ Service account file not found: assets/config/service_account.json');
      return;
    }
    
    final serviceAccountData = json.decode(await serviceAccountFile.readAsString());
    print('✅ Service account file loaded');
    print('📧 Service account email: $serviceAccountEmail\n');
    
    // Create JWT token
    final now = DateTime.now();
    final expiry = now.add(const Duration(hours: 1));
    
    final Map<String, dynamic> claims = {
      'iss': serviceAccountData['client_email'],
      'scope': 'https://www.googleapis.com/auth/spreadsheets',
      'aud': 'https://oauth2.googleapis.com/token',
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
    };
    
    final jwt = JWT(claims);
    final token = jwt.sign(RSAPrivateKey(serviceAccountData['private_key']), algorithm: JWTAlgorithm.RS256);
    
    // Exchange JWT for access token
    final tokenResponse = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': token,
      },
    );
    
    if (tokenResponse.statusCode != 200) {
      print('❌ Failed to get access token: ${tokenResponse.statusCode}');
      print('Response: ${tokenResponse.body}');
      return;
    }
    
    final tokenData = json.decode(tokenResponse.body);
    final accessToken = tokenData['access_token'];
    print('✅ Access token obtained successfully\n');
    
    // Test 1: Read spreadsheet metadata
    print('🔍 Test 1: Reading spreadsheet metadata...');
    final metadataResponse = await http.get(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    
    if (metadataResponse.statusCode == 200) {
      final metadata = json.decode(metadataResponse.body);
      print('✅ Can read spreadsheet metadata');
      print('📊 Spreadsheet title: ${metadata['properties']['title']}');
      
      // List all sheets
      final sheets = metadata['sheets'] as List;
      print('📋 Available sheets:');
      for (final sheet in sheets) {
        final sheetName = sheet['properties']['title'];
        print('   - $sheetName');
      }
      print('');
    } else {
      print('❌ Cannot read spreadsheet metadata: ${metadataResponse.statusCode}');
      print('Response: ${metadataResponse.body}\n');
      return;
    }
    
    // Test 2: Try to read from Players sheet
    print('🔍 Test 2: Reading from Players sheet...');
    final playersResponse = await http.get(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Players!A1:D5'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    
    if (playersResponse.statusCode == 200) {
      print('✅ Can read from Players sheet');
    } else {
      print('❌ Cannot read from Players sheet: ${playersResponse.statusCode}');
      print('Response: ${playersResponse.body}');
    }
    print('');
    
    // Test 3: Try to read from GameRoster sheet
    print('🔍 Test 3: Reading from GameRoster sheet...');
    final rosterResponse = await http.get(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/GameRoster!A1:C5'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    
    if (rosterResponse.statusCode == 200) {
      print('✅ Can read from GameRoster sheet');
    } else {
      print('❌ Cannot read from GameRoster sheet: ${rosterResponse.statusCode}');
      print('Response: ${rosterResponse.body}');
    }
    print('');
    
    // Test 4: Try to write to GameRoster sheet (append a test row)
    print('🔍 Test 4: Testing write permissions to GameRoster sheet...');
    final testData = {
      'values': [['TEST_GAME', 'TEST_PLAYER', 'TEST_STATUS']],
      'majorDimension': 'ROWS',
    };
    
    final writeResponse = await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/GameRoster!A1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(testData),
    );
    
    if (writeResponse.statusCode == 200) {
      print('✅ Can write to GameRoster sheet - permissions are correct!');
      print('🧹 Test row added successfully (you may want to delete it manually)');
    } else {
      print('❌ Cannot write to GameRoster sheet: ${writeResponse.statusCode}');
      print('Response: ${writeResponse.body}');
      
      if (writeResponse.statusCode == 403) {
        print('\n💡 This is a permissions issue. The service account needs Editor access.');
      } else if (writeResponse.statusCode == 404) {
        print('\n💡 This could mean:');
        print('   1. The GameRoster sheet doesn\'t exist');
        print('   2. The service account doesn\'t have access to this specific sheet');
        print('   3. The spreadsheet ID is incorrect');
      }
    }
    
    print('\n📋 Summary:');
    print('🔗 Spreadsheet URL: https://docs.google.com/spreadsheets/d/$spreadsheetId');
    print('📧 Service account to add: $serviceAccountEmail');
    print('🔑 Required permission level: Editor');
    print('\n💡 If write tests failed, please:');
    print('   1. Open the spreadsheet URL above');
    print('   2. Click Share button');
    print('   3. Add the service account email with Editor permissions');
    print('   4. Make sure the GameRoster sheet exists');
    
  } catch (e) {
    print('❌ Error during testing: $e');
  }
}
