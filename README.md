# Offline-First Hockey Stats Tracker

This is a mobile application built with Flutter designed to track core hockey statistics offline and synchronize them with a central Google Sheet.

## Project Goal

To enable users to easily record hockey game events (Shots and Penalties) on a mobile device, even without an internet connection, and have this data reliably stored in a Google Sheet for subsequent analysis and decision-making.

## Architecture

*   **Client:** Flutter Mobile Application (Android & iOS)
*   **Client Local Storage:** Embedded Hive Database within the Flutter App
*   **Cloud Backend:** Google Sheets Document
*   **Integration Mechanism:** Google Sheets API (accessed via Flutter `googleapis` package)
*   **Core Operational Logic:** Client-side Synchronization Service

## Current Features

*   **Game Selection:** Users can select the current game they are tracking stats for.
*   **Log Shots:** Record shot events (all shots are considered on goal by default), including the shooter, optional assists, and players on ice for goals. All data entry functions fully offline.
*   **Log Penalties:** Record penalty events, including the penalized player, penalty type, and duration. All data entry functions fully offline.
*   **View Local Stats:** Review events logged for the current game and view basic statistics based on locally stored data.
*   **Real-time Stats Updates:** View real-time score and shot count updates during game tracking.
*   **Period Selection:** Users can select the current period (P1, P2, P3, OT) for tracking shots and penalties, with the selected period persisting across relevant screens and clearly indicated in the UI.
*   **Enhanced Game Details Display:** Game information on the stats tracking screen is presented in an improved card-based layout, featuring team logos, informational icons, and better data formatting.
*   **Team Logo Integration:** Team logos are displayed in key areas like game details and team selection, enhancing visual appeal. Logos are managed via a JSON configuration (`assets/data/team_logos.json`) and a dedicated utility (`lib/utils/team_utils.dart`), also supporting team-specific colors.
*   **Simplified Shot Logging:** Streamlined shot logging process that focuses on essential information, automatically considering all logged shots as on goal.
*   **Standardized Google Sheets Integration:** Consistent 13-column structure in the Events sheet for reliable data synchronization and analysis.

## Planned Features

### Enhanced Stats Tracking
*   Implement shot location tracking with a visual rink diagram
*   Add shot type classification (wrist shot, slap shot, etc.)
*   Track time on ice for players
*   Add face-off tracking and win/loss statistics

### Team Management
*   Create a team management interface for adding/editing teams
*   Implement roster management with player positions and numbers
*   Add line combination presets for quick player selection
*   Support multiple teams in the same app instance

### Advanced Analytics
*   Implement heat maps for shot locations
*   Add advanced statistics (Corsi, Fenwick, etc.)
*   Create detailed player performance reports
*   Add trend analysis over multiple games

### UI/UX Improvements
*   Add dark mode support
*   Implement customizable color themes per team
*   Add animations for stat updates
*   Create a more intuitive player selection interface
*   Add quick action shortcuts for common operations

### Data Management
*   Implement data export to CSV/Excel
*   Add backup/restore functionality
*   Create a web dashboard for viewing stats
*   Add support for importing data from other sources

### Sync and Sharing
*   Add real-time sync between multiple devices
*   Implement team sharing functionality
*   Add support for exporting game reports
*   Create a coach's view for team management

### Game Management
*   Add game clock functionality
*   Implement period duration tracking
*   Add support for tracking timeouts
*   Create a game summary report generator

## Data Model

The application manages data based on the following entities:

*   **Player:** Stores player information (jersey number, name, team ID, position).
*   **Game:** Stores game details (date, opponent, location).
*   **Team:** Stores team data including name, logo information (from `assets/data/team_logos.json`), and colors.
*   **GameEvent:** Records individual game events with:
    - Core fields: ID, GameID, Timestamp, Period, EventType, Team
    - Player fields: PrimaryPlayerID (shooter/penalized player), AssistPlayer1ID, AssistPlayer2ID
    - Event details: IsGoal, PenaltyType, PenaltyDuration
    - Additional data: YourTeamPlayersOnIce (for goals)
    - Sync status: Boolean flag for tracking synchronization state

## Technical Details

*   Built with the Flutter SDK.
*   Utilizes a local database (Hive) for offline data persistence.
*   Integrates with the Google Sheets API for cloud synchronization:
    - Standardized 13-column structure for Events sheet
    - Robust data validation and error handling
    - Detailed logging for troubleshooting
*   Manages team logos and colors through:
    - JSON configuration file (`assets/data/team_logos.json`)
    - TeamUtils utility class (`lib/utils/team_utils.dart`)
*   Assets (logos, data files) are declared in `pubspec.yaml`
*   Key UI enhancements include:
    - Period selection across stat logging screens
    - Improved game details display
    - Simplified shot logging interface

## Getting Started

1. Clone the repository
2. Install Flutter dependencies:
   ```
   flutter pub get
   ```
3. Set up your Google Sheets document following the structure in `GOOGLE_SHEETS_SETUP.md`
4. Run the app:
   ```
   flutter run
   ```

For detailed setup instructions and documentation:
- See `HOW_TO_RUN.md` for running the app
- See `GOOGLE_SHEETS_SETUP.md` for Google Sheets configuration
- See `IMPLEMENTATION_SUMMARY.md` for technical details
- See `LOGO_INSTRUCTIONS.md` for customizing team logos
