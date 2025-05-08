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

## Events Sheet

This sheet will be populated automatically by the app as you log shots and penalties. You don't need to create any data here.

## Important Notes

1. **The ID column is critical** - Each player and game must have a unique ID in column A
2. **Headers** - Include headers in row 1 (the app reads from row 2 onward)
3. **Empty cells** - The app can handle some empty cells, but required fields must be present
4. **Data types** - Jersey numbers must be numeric values

If you're seeing errors like "Skipping invalid player row", it's likely because your sheet is missing the ID column or has columns in a different order than expected.

## Troubleshooting

Common errors and their solutions:

- **"Skipping invalid player row"**: Check that:
  - You have a unique ID for each player in Column A
  - Jersey numbers are valid numbers (0 or greater)
- **"Error parsing date for game"**: Ensure dates are in YYYY-MM-DD format
- **"Authentication failed"**: Sign in again through the app
- **"No player/game data found in the sheet"**: Verify your sheet names are exactly "Players", "Games", and "Events"

## Recent Updates

- **Jersey number 0 is now supported**: The app has been updated to support players with jersey number 0.
