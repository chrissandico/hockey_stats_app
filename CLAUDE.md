# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

An offline-first Flutter mobile application for tracking hockey statistics (shots, penalties, goals, attendance) that synchronizes with Google Sheets. Supports multiple teams using team-based authentication with service accounts.

**Key Technologies**: Flutter, Hive (local database), Google Sheets API, Provider (state management)

## Common Commands

### Development
```bash
# Install dependencies
flutter pub get

# Run on specific platforms
flutter run -d chrome          # Web
flutter run -d android          # Android
flutter run -d ios              # iOS

# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check Flutter environment
flutter doctor

# Generate Hive type adapters after model changes
flutter pub run build_runner build --delete-conflicting-outputs
```

### Testing & Building
```bash
# Run tests
flutter test

# Build for production (Android)
flutter build apk --release

# Build for production (iOS)
flutter build ios --release
```

## Architecture Overview

### Core Architecture Pattern: Offline-First with Background Sync

The app follows an **offline-first architecture** where:
1. All data is stored locally in Hive boxes for immediate access
2. Google Sheets serves as the source of truth for shared/synced data
3. A background sync service periodically reconciles local and remote data
4. Network operations are batched and queued when offline

### Key Services Layer

**CentralizedDataService** (`lib/services/centralized_data_service.dart`)
- Central hub for data access across the app
- Prioritizes Google Sheets data, falls back to local Hive storage
- Implements 2-minute caching to reduce API calls
- All stats calculations should go through this service

**SheetsService** (`lib/services/sheets_service.dart`)
- Handles all Google Sheets API operations
- Manages authentication with Google (OAuth for individual users)
- Syncs Players, Games, Events, Rosters, and Attendance sheets
- **Critical**: Events sheet uses standardized 13-column structure

**TeamAuthService** (`lib/services/team_auth_service.dart`)
- Multi-team authentication system
- Uses service account authentication (not OAuth)
- Teams stored in "Teams" sheet with TeamID/TeamName/Password
- All data filtered by teamId for team isolation

**BackgroundSyncService** (`lib/services/background_sync_service.dart`)
- Automatic background sync every 5 minutes
- Batches network operations (5 second delay, max 10 items per batch)
- Event-level locks prevent race conditions during sync
- Triggers sync when device comes online

**ConnectivityService** (`lib/services/connectivity_service.dart`)
- Monitors network connectivity status
- Broadcasts connectivity changes via stream
- Used to determine when to attempt network operations

**MemoryCacheService** (`lib/services/memory_cache_service.dart`)
- In-memory caching for frequently accessed data (players, games)
- Reduces Hive box reads for performance

### Data Models (Hive Objects)

All models in `lib/models/data_models.dart` use Hive annotations:

- **Player**: jerseyNumber, teamId, position
- **Game**: date, opponent, location, teamId, gameType (R/P/E)
- **GameEvent**: Tracks shots/penalties with period, eventType, primaryPlayerId, assists, isGoal, penaltyType, isSynced flag
- **GameRoster**: Tracks which players are on the roster for a game
- **GameAttendance**: Tracks player attendance with attendance type
- **GoalSituation**: Enum for evenStrength/powerPlay/shortHanded

**Important**: Game model has migration logic in `HiveMigrationManager` for adding teamId and gameType fields.

### Authentication Flow

1. **Team Login** (`TeamLoginScreen`) → Validates password against Teams sheet
2. **Auth Wrapper** (`AuthWrapperScreen`) → Determines if team is logged in
3. **Game Selection** (`GameSelectionScreen`) → Shows team-specific games
4. **Stats Tracking** → All operations filtered by current teamId

### Google Sheets Structure

The app expects these sheets in the spreadsheet:

- **Teams**: TeamID | TeamName | Password | LogoFileName
- **Players**: ID | Jersey Number | Team ID | Position
- **Games**: ID | Date | Opponent | Location | TeamID | GameType
- **Events**: 13 columns (ID, GameID, Timestamp, Period, EventType, Team, PrimaryPlayerID, AssistPlayer1ID, AssistPlayer2ID, IsGoal, PenaltyType, PenaltyDuration, YourTeamPlayersOnIce)
- **GameRosters**: GameID | PlayerID | Synced
- **GameAttendance**: GameID | PlayerID | AttendanceType | Synced

### Team Logos & Assets

- Logo configuration: `assets/data/team_logos.json`
- Logo files: `assets/logos/` (PNG format recommended)
- TeamUtils (`lib/utils/team_utils.dart`) handles logo loading and team colors
- Assets must be declared in `pubspec.yaml` under `flutter: assets:`

### Performance Optimizations

- **Batch sync operations**: Use 5-second delay, max 10 items
- **Memory caching**: MemoryCacheService caches frequently accessed data
- **Provider pattern**: Minimize rebuilds, use `select` for targeted updates
- **Lazy loading**: Load data only when needed, especially for stats screens
- **Wakelock**: Keep screen on during game stats tracking (`WakelockService`)

### Screen Navigation Flow

```
TeamLoginScreen (if not logged in)
    ↓
GameSelectionScreen (shows team's games, can create new games)
    ↓
LogStatsScreen (main hub: view stats, log events)
    ├→ LogShotScreen / LogGoalScreen
    ├→ LogPenaltyScreen
    ├→ ViewStatsScreen (detailed statistics)
    ├→ AttendanceDialog (manage player attendance)
    ├→ EditShotListScreen (edit/delete events)
    └→ SyncSettingsScreen (configure sync preferences)
```

## Important Implementation Notes

### Data Sync Patterns

**When adding/editing events**:
1. Save to local Hive box immediately with `isSynced: false`
2. Queue for background sync (BackgroundSyncService handles batching)
3. Update UI optimistically (show saved data immediately)
4. Sync marks items as `isSynced: true` on success

**When reading data**:
1. Always use `CentralizedDataService.getCurrentGameEvents()` for stats
2. This ensures Google Sheets is source of truth when online
3. Falls back to local data when offline
4. Use `forceRefresh: true` parameter to bypass cache

### Multi-Team Data Isolation

All data operations MUST filter by `teamId`:
- Use `TeamContextService.getCurrentTeamId()` to get current team
- Filter Hive queries by teamId
- Include teamId when creating new games/events
- Service account has access to all teams' data in same spreadsheet

### Period Management

Periods are represented as integers:
- 1, 2, 3 = regular periods
- 4 = Overtime (displayed as "OT")
- Period persists across navigation using shared state

### Hive Data Reset

To reset all local data (for testing or corruption recovery):
1. Set `performReset = true` in `lib/main.dart`
2. Run app once (it will reset and exit)
3. Set `performReset = false`
4. Restart app

### Service Account Authentication

- Service account JSON: `assets/config/service_account.json`
- Service account email must have Editor access to spreadsheet
- JWT signing implemented using `dart_jsonwebtoken` package
- See `MULTI_TEAM_SETUP.md` for complete setup instructions

### Error Handling

- Network errors: Use `NetworkUtils.isNetworkError()` and `NetworkUtils.getNetworkErrorMessage()`
- Sync errors: Use `SyncErrorUtils` for user-friendly error messages
- Corrupted Hive boxes: `HiveMigrationManager.recoverCorruptedBox()` handles recovery
- Critical errors: App shows `AppErrorScreen` with reset option

## File Organization

```
lib/
├── main.dart                    # App initialization, Hive setup
├── models/                      # Hive data models with type adapters
│   ├── data_models.dart         # Core models (Player, Game, GameEvent, etc.)
│   ├── custom_adapters.dart     # Hive type adapter registration
│   └── team_model.dart          # Team model (not stored in Hive)
├── screens/                     # UI screens
│   ├── auth_wrapper_screen.dart       # Authentication routing
│   ├── team_login_screen.dart         # Team password login
│   ├── game_selection_screen.dart     # Game list and selection
│   ├── log_stats_screen.dart          # Main stats hub
│   ├── log_shot_screen.dart           # Shot logging
│   ├── log_goal_screen.dart           # Goal logging with assists
│   ├── log_penalty_screen.dart        # Penalty logging
│   ├── view_stats_screen.dart         # Detailed statistics view
│   ├── attendance_dialog.dart         # Attendance management
│   └── edit_shot_list_screen.dart     # Event editing
├── services/                    # Business logic and data services
│   ├── centralized_data_service.dart  # Central data access layer
│   ├── sheets_service.dart            # Google Sheets API
│   ├── team_auth_service.dart         # Team authentication
│   ├── background_sync_service.dart   # Background sync orchestration
│   ├── connectivity_service.dart      # Network monitoring
│   ├── memory_cache_service.dart      # In-memory caching
│   ├── stats_service.dart             # Statistics calculations
│   ├── service_account_auth.dart      # Service account JWT auth
│   └── pdf_service.dart               # PDF generation for stats
├── widgets/                     # Reusable UI components
│   ├── connectivity_indicator.dart    # Network status indicator
│   ├── goalie_stats_widget.dart       # Goalie statistics display
│   └── score_summary_widget.dart      # Score summary card
└── utils/                       # Utility functions
    ├── team_utils.dart          # Team logo and color utilities
    ├── network_utils.dart       # Network error handling
    └── sync_error_utils.dart    # Sync error messages
```

## Key Constraints & Best Practices

### When Modifying Data Models
1. Update the model in `data_models.dart` with Hive annotations
2. Run `flutter pub run build_runner build --delete-conflicting-outputs`
3. Handle migration for existing data if adding new fields (see `HiveMigrationManager`)
4. Test with both empty and populated Hive boxes

### When Adding New Sync Operations
1. Add sync logic to `SheetsService`
2. Queue operations through `BackgroundSyncService` batching system
3. Use event-level locks to prevent race conditions
4. Mark items with `isSynced` flag for tracking
5. Handle both online and offline scenarios

### When Working with Stats
1. Always use `CentralizedDataService` for data access (never read Hive directly for stats)
2. Google Sheets is source of truth, local is cache
3. Use `forceRefresh: true` after sync operations
4. Cache stats calculations when possible (they're expensive)

### When Testing Multi-Team Features
1. Create test teams in Teams sheet with different TeamIDs
2. Ensure all test data has correct teamId values
3. Log in as different teams to verify data isolation
4. Test sync behavior across teams

## Common Troubleshooting

**"JWT signing is not implemented"**: Service account setup incomplete, check `service_account.json`

**"The caller does not have permission" (403)**: Spreadsheet not shared with service account email

**"No teams found"**: Teams sheet missing or empty in Google Sheets

**Duplicate events after sync**: Check that event IDs are unique and `isSynced` flag is being set correctly

**Stats not updating**: Use `forceRefresh: true` on `CentralizedDataService`, clear cache

**Build runner fails**: Delete `.dart_tool/` and `lib/models/data_models.g.dart`, then re-run

## Documentation Files

- `README.md` - Project overview and architecture
- `SETUP.md` - Initial setup instructions
- `HOW_TO_RUN.md` - Running the app on different platforms
- `GOOGLE_SHEETS_SETUP.md` - Google Sheets structure and permissions
- `MULTI_TEAM_SETUP.md` - Multi-team configuration and service account setup
- `LOGO_INSTRUCTIONS.md` - Customizing team logos
- `NEW_USER_GUIDE.md` - Guide for new users
- `ADMIN_GUIDE.md` - Administrator instructions
