# Multi-Team Setup Guide for Hockey Stats App

This guide explains how to set up and use the multi-team functionality in the Hockey Stats App.

## Overview

The Hockey Stats App now supports multiple teams using the same Google Sheets spreadsheet. Each team has its own password and can only see and manage their own data. This allows multiple teams to use the same app and spreadsheet without seeing each other's data.

## Prerequisites

### Service Account Setup

The app uses a Google Service Account for authentication with Google Sheets. This eliminates the need for individual Google accounts for each user.

1. **Service Account JSON**: The service account JSON file should be placed in `assets/config/service_account.json`.

2. **Share Spreadsheet**: 
   - **CRITICAL STEP**: You MUST share your Google Sheets spreadsheet with the service account email address.
   - Open your Google Sheets spreadsheet in a browser
   - Click the "Share" button in the top right corner
   - Enter the service account email: `hockey-stats-service-new@hockey-stats-viewer.iam.gserviceaccount.com`
   - Set permission to "Editor" to allow the service account to read and write data
   - Click "Send" (no email notification is needed)
   
   If this step is skipped, you will get a 403 PERMISSION_DENIED error when trying to access the spreadsheet.

3. **Enable Google Sheets API**: 
   - Make sure the Google Sheets API is enabled for your Google Cloud project
   - Go to the [Google Cloud Console](https://console.cloud.google.com/)
   - Select your project (hockey-stats-viewer)
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google Sheets API" and enable it if it's not already enabled

4. **JWT Library**: For proper authentication, you need to add a JWT library to the project and implement RSA-SHA256 signing.

## Google Sheets Setup

### 1. Create a "Teams" Sheet

Add a new sheet called "Teams" to your Google Sheets spreadsheet with the following columns:

| TeamID | TeamName | Password |
|--------|----------|----------|
| your_team | WaxersU12AA | waxers2024 |
| team_rockets | Rockets | rockets2024 |
| team_lightning | Lightning | lightning2024 |

- **TeamID**: A unique identifier for the team (e.g., "your_team", "team_rockets")
- **TeamName**: The display name of the team (e.g., "WaxersU12AA", "Rockets")
- **Password**: The password that team members will use to access their team's data

### 2. Add TeamID to Games Sheet

Add a new column E called "TeamID" to your Games sheet:

| ID | Date | Opponent | Location | TeamID |
|----|------|----------|----------|--------|
| game_001 | 2023-05-15 | Rivals | Home Arena | your_team |
| game_002 | 2023-05-22 | Chiefs | Away Arena | team_rockets |

- Set the TeamID for each game to match the team it belongs to
- All existing games should be updated with the appropriate TeamID
- New games will automatically be assigned the correct TeamID based on the logged-in team

### 3. Players Sheet

The Players sheet already has a TeamID column (Column C), so no changes are needed. Just ensure all players have the correct TeamID assigned.

## App Usage

### Team Login

When users open the app, they will now see a team login screen:

1. Enter your team's password (e.g., "waxers2024" for the WaxersU12AA team)
2. The app will automatically detect which team you belong to
3. You will only see games and players for your team

### Team Data Isolation

- Each team can only see and manage their own games, players, and stats
- Teams cannot see or modify data from other teams
- All data is stored in the same Google Sheets spreadsheet, but filtered by TeamID

## Adding New Teams

To add a new team:

1. Add a new row to the Teams sheet with the team's information:
   - TeamID: A unique identifier (e.g., "team_newteam")
   - TeamName: The display name (e.g., "New Team")
   - Password: The password for team members (e.g., "newteam2024")

2. Add players for the new team to the Players sheet with the correct TeamID

3. Team members can now log in using the team password

## Implementing JWT Signing

The current implementation requires proper JWT signing for service account authentication. To implement this:

1. **Add JWT Library**: Add a JWT library to the project, such as `dart_jsonwebtoken`:
   ```yaml
   dependencies:
     dart_jsonwebtoken: ^2.0.0
   ```

2. **Implement JWT Signing**: Update the `_createJwt` method in `lib/services/service_account_auth.dart` to use the JWT library for proper RSA-SHA256 signing:
   ```dart
   String _createJwt(Map<String, dynamic> claims) {
     final privateKey = _serviceAccountData!['private_key'];
     final jwt = JWT(claims);
     return jwt.sign(RSAPrivateKey(privateKey), algorithm: JWTAlgorithm.RS256);
   }
   ```

## Troubleshooting

### Authentication Issues

- If you see "JWT signing is not implemented" errors, you need to implement proper JWT signing as described above.
- Ensure the service account JSON file is correctly formatted and contains all required fields.
- Verify that the Google Sheets spreadsheet is shared with the service account email.

### Team Login Issues

- Ensure the team password is entered correctly (passwords are case-sensitive).
- Check that the team exists in the Teams sheet.
- Verify that the TeamID in the Teams sheet matches the TeamID used in the Games and Players sheets.

### Data Visibility Issues

- If a team cannot see their games, check that the games have the correct TeamID in the Games sheet.
- If a team cannot see their players, check that the players have the correct TeamID in the Players sheet.

## Technical Details

The multi-team functionality works by:

1. Authenticating with Google Sheets using a service account
2. Reading team information from the Teams sheet
3. Using the TeamID field to filter games and players
4. Securely storing the current team ID on the device
5. Filtering all data operations by the current team ID

This ensures that each team only sees and modifies their own data, while still using the same Google Sheets spreadsheet for all teams.
