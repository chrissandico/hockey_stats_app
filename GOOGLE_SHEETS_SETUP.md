# Google Sheets Setup Guide for Hockey Stats App

This guide explains how to set up your Google Sheets to work with the Hockey Stats App.

## Players Sheet Setup

The app expects the "Players" sheet to have these columns:

1. **Column A: ID (required)** - A unique identifier for each player
   - This must be a non-empty string (e.g., "player_1", "p001")
   - Each player must have a unique ID

2. **Column B: Jersey Number (required)** - The player's jersey number
   - Must be a number greater than or equal to 0 (jersey #0 is now supported)

3. **Column C: Team ID (optional)** - Which team the player belongs to
   - Defaults to "your_team" if not provided
   - Use "your_team" for your own team's players
   - Use any other consistent identifier for opponent players

### Example Players Sheet:
```
ID          | Jersey Number | Team ID
player_1    | 4             | your_team
player_2    | 2             | your_team
player_3    | 17            | your_team
player_4    | 91            | your_team
player_5    | 0             | your_team
```

## Games Sheet Setup

The "Games" sheet should have these columns:

1. **Column A: ID (required)** - A unique identifier for each game
   - Can be any string format (e.g., "game_2023_05_15")

2. **Column B: Date (required)** - The game date
   - Use YYYY-MM-DD format (e.g., "2023-05-15")
   - MM/DD/YYYY format is also supported

3. **Column C: Opponent (required)** - The name of the opponent team

4. **Column D: Location (optional)** - Where the game is played

### Example Games Sheet:
```
ID                      | Date       | Opponent | Location
game_2023_05_15_rivals  | 2023-05-15 | Rivals   | Home Arena
game_2023_05_22_chiefs  | 2023-05-22 | Chiefs   | Away Arena
```

## Events Sheet Setup

The Events sheet is populated automatically by the app as you log shots and penalties. The sheet has the following columns:

1. **Column A: ID** - Unique identifier for each event
2. **Column B: GameID** - ID of the game this event belongs to
3. **Column C: Timestamp** - When the event occurred
4. **Column D: Period** - Game period (1, 2, 3, or 4 for OT)
5. **Column E: EventType** - Type of event ("Shot" or "Penalty")
6. **Column F: Team** - Team involved ("your_team" or "opponent")
7. **Column G: PrimaryPlayerID** - ID of the shooter or penalized player
8. **Column H: AssistPlayer1ID** - First assist player ID (for goals)
9. **Column I: AssistPlayer2ID** - Second assist player ID (for goals)
10. **Column J: IsGoal** - Whether the shot was a goal (true/false)
11. **Column K: PenaltyType** - Type of penalty (for penalty events)
12. **Column L: PenaltyDuration** - Duration in minutes (for penalty events)
13. **Column M: YourTeamPlayersOnIce** - Comma-separated list of player IDs on ice for goals

### Example Events Sheet:
```
ID          | GameID    | Timestamp           | Period | EventType | Team      | PrimaryPlayerID | AssistPlayer1ID | AssistPlayer2ID | IsGoal | PenaltyType | PenaltyDuration | YourTeamPlayersOnIce
event_001   | game_001  | 2023-05-15 19:15:00 | 1      | Shot      | your_team | player_1       | player_2        | player_3        | true   |             |                | player_1,player_2,player_3,player_4,player_5
event_002   | game_001  | 2023-05-15 19:20:00 | 1      | Penalty   | opponent  | opp_player_1   |                 |                 |        | Tripping    | 2              |
event_003   | game_001  | 2023-05-15 19:25:00 | 2      | Shot      | your_team | player_4       |                 |                 | false  |             |                |
```

## User Access Setup

Before users can access the app, two important steps must be completed:

1. **Add Test Users in OAuth Consent Screen**
   - Go to the Google Cloud Console
   - Navigate to "APIs & Services" > "OAuth consent screen"
   - Under "Test users", click "Add Users"
   - Enter the Gmail address of each user who needs access
   - Click "Save" to add the test users

2. **Share the Google Sheet**
   - Open Google Drive in your web browser
   - Navigate to the spreadsheet
   - Click the "Share" button in the top-right corner
   - In the "Share with people and groups" field, enter the user's Gmail address
   - Set permission level to "Editor" (required for the app to write data)
   - Click "Send" to share the sheet

Both steps are required - users must be both added as test users AND have editor access to the spreadsheet to use the app successfully.

## Important Notes

1. **The ID column is critical** - Each player, game, and event must have a unique ID in column A
2. **Headers** - Include headers in row 1 (the app reads from row 2 onward)
3. **Empty cells** - The app can handle empty cells for optional fields
4. **Data types** - Jersey numbers must be numeric values
5. **Players on Ice** - Only tracked for goals scored by your team
6. **Timestamps** - Must be in a format parseable by DateTime.parse()

## Troubleshooting

Common errors and their solutions:

- **"Skipping invalid player row"**: Check that:
  - You have a unique ID for each player in Column A
  - Jersey numbers are valid numbers (0 or greater)
- **"Error parsing date for game"**: Ensure dates are in YYYY-MM-DD format
- **"Authentication failed"**: Sign in again through the app
- **"No player/game data found in the sheet"**: Verify your sheet names are exactly "Players", "Games", and "Events"
- **"The caller does not have permission" (403 error)**: Check that:
  - The user's Gmail address has been added as a test user in the OAuth consent screen
  - The Google Sheet has been shared with the user's Gmail address with Editor permissions

## Recent Updates

- **Jersey number 0 is now supported**: The app has been updated to support players with jersey number 0.
- **Events sheet structure updated**: The Events sheet now uses a standardized 13-column structure for better data organization.
