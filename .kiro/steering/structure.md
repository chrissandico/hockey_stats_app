# Project Structure

## Root Directory Organization

```
hockey_stats_app/
├── lib/                    # Main application code
├── assets/                 # Static assets (logos, data, config)
├── android/                # Android platform-specific code
├── ios/                    # iOS platform-specific code
├── web/                    # Web platform-specific code
├── windows/                # Windows platform-specific code
├── linux/                  # Linux platform-specific code
├── macos/                  # macOS platform-specific code
├── test/                   # Test files
├── .kiro/                  # Kiro AI assistant configuration
├── build/                  # Build output (generated)
└── .dart_tool/             # Dart tooling (generated)
```

## Core Application Structure (`lib/`)

### Entry Point
- **`main.dart`**: App initialization, Hive setup, adapter registration, error handling

### Models (`lib/models/`)
Data models with Hive persistence:
- **`data_models.dart`**: Core entities (Player, Game, GameEvent, GameRoster, GameAttendance, EmailSettings, SyncPreferences, GoalSituation)
- **`data_models.g.dart`**: Generated Hive TypeAdapters (do not edit manually)
- **`custom_adapters.dart`**: Custom Hive adapters and migration logic (HiveMigrationManager)
- **`team_model.dart`**: Team configuration model

### Screens (`lib/screens/`)
Full-page UI components:
- **`auth_wrapper_screen.dart`**: Authentication flow wrapper
- **`team_login_screen.dart`**: Team-specific authentication
- **`game_selection_screen.dart`**: Game list and selection
- **`log_stats_screen.dart`**: Main stat tracking hub
- **`log_shot_screen.dart`**: Shot/goal logging interface
- **`log_goal_screen.dart`**: Goal details and assists
- **`log_penalty_screen.dart`**: Penalty logging
- **`edit_shot_list_screen.dart`**: Edit recorded shots
- **`view_stats_screen.dart`**: Statistics display
- **`attendance_dialog.dart`**: Player attendance management
- **`app_settings_screen.dart`**: Application settings
- **`sync_settings_screen.dart`**: Sync configuration
- **`unsynced_events_screen.dart`**: View pending sync events

### Services (`lib/services/`)
Business logic and external integrations:
- **`centralized_data_service.dart`**: Single source of truth for data (Google Sheets primary)
- **`sheets_service.dart`**: Google Sheets API integration
- **`service_account_auth.dart`**: JWT-based service account authentication
- **`team_auth_service.dart`**: Team-specific authentication logic
- **`team_context_service.dart`**: Multi-team context management
- **`background_sync_service.dart`**: Automatic background synchronization
- **`connectivity_service.dart`**: Network status monitoring
- **`memory_cache_service.dart`**: In-memory caching layer
- **`stats_service.dart`**: Statistics calculation logic
- **`line_configuration_service.dart`**: Line/roster management
- **`pdf_service.dart`**: PDF generation for reports
- **`email_service.dart`**: Email integration
- **`wakelock_service.dart`**: Screen wake lock management

### Widgets (`lib/widgets/`)
Reusable UI components:
- **`player_selection_widget.dart`**: Player picker with search/filter
- **`goalie_stats_widget.dart`**: Goalie statistics display
- **`score_summary_widget.dart`**: Game score summary
- **`goal_situation_dialog.dart`**: Goal situation selector (ES/PP/SH)
- **`connectivity_indicator.dart`**: Network status indicator
- **`email_dialog.dart`**: Email composition dialog
- **`share_dialog.dart`**: Share options dialog

### Utils (`lib/utils/`)
Helper functions and utilities:
- **`team_utils.dart`**: Team logo/color management, JSON config loading
- **`network_utils.dart`**: Network connectivity checks and error handling
- **`sync_error_utils.dart`**: Sync error categorization and messaging

## Assets Structure (`assets/`)

```
assets/
├── logos/                  # Team logos
│   ├── generic_logo.svg
│   ├── stars_logo.png
│   ├── waxers_logo.png
│   └── your_team_logo.svg
├── data/                   # Configuration files
│   └── team_logos.json     # Team logo/color mappings
└── config/                 # Service credentials
    └── service_account.json # Google service account (not in git)
```

## Documentation Files

### User Documentation
- **`README.md`**: Project overview and quick start
- **`NEW_USER_GUIDE.md`**: End-user setup instructions
- **`ADMIN_GUIDE.md`**: Administrator guide for user management
- **`HOW_TO_RUN.md`**: Developer run instructions
- **`GOOGLE_SHEETS_SETUP.md`**: Google Sheets configuration
- **`LOGO_INSTRUCTIONS.md`**: Team logo customization
- **`MULTI_TEAM_SETUP.md`**: Multi-team configuration
- **`RELEASE_NOTES.md`**: Version history and changes

### Technical Documentation
- **`IMPLEMENTATION_SUMMARY.md`**: Technical implementation details
- **`COMPLETE_CHANGES_SUMMARY.md`**: Comprehensive change log
- Various feature-specific summaries (e.g., `DUPLICATE_EVENTS_FIX_SUMMARY.md`)

## Platform-Specific Directories

### Android (`android/`)
- **`app/build.gradle.kts`**: App-level Gradle configuration
- **`build.gradle.kts`**: Project-level Gradle configuration
- **`app/src/main/AndroidManifest.xml`**: Android manifest
- **`app/google-services.json`**: Firebase configuration (if used)
- **`hockey_stats_app.keystore`**: Release signing keystore
- **`key.properties`**: Keystore credentials (not in git)

### iOS (`ios/`)
- **`Runner.xcodeproj/`**: Xcode project
- **`Runner/Info.plist`**: iOS app configuration
- **`Runner/AppDelegate.swift`**: iOS app delegate

## Code Generation

Generated files (do not edit manually):
- `lib/models/data_models.g.dart`: Hive TypeAdapters
- Platform plugin registrants in each platform directory

Regenerate with:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Naming Conventions

### Files
- **Screens**: `*_screen.dart` (e.g., `game_selection_screen.dart`)
- **Services**: `*_service.dart` (e.g., `sheets_service.dart`)
- **Widgets**: `*_widget.dart` or `*_dialog.dart`
- **Utils**: `*_utils.dart` (e.g., `team_utils.dart`)
- **Models**: `*_model.dart` or `data_models.dart`

### Classes
- **Screens**: `*Screen` (e.g., `GameSelectionScreen`)
- **Services**: `*Service` (e.g., `SheetsService`)
- **Widgets**: `*Widget` or `*Dialog`
- **Models**: PascalCase entity names (e.g., `Player`, `Game`)

### Hive Boxes
- `'players'`: Player entities
- `'games'`: Game entities
- `'gameEvents'`: GameEvent entities
- `'emailSettings'`: Email configuration
- `'gameRoster'`: Game roster data
- `'gameAttendance'`: Attendance records
- `'syncPreferences'`: Sync settings

## Import Conventions

Use package imports for internal files:
```dart
import 'package:hockey_stats_app/models/data_models.dart';
import 'package:hockey_stats_app/services/sheets_service.dart';
import 'package:hockey_stats_app/screens/game_selection_screen.dart';
```

## State Management Pattern

- **Provider**: Used at app level for dependency injection (see `main.dart`)
- **Hive Boxes**: Direct access in services, reactive updates via `ValueListenableBuilder`
- **StatefulWidget**: For local UI state in screens and widgets
- **Services**: Singleton pattern for shared services (e.g., `CentralizedDataService`)

## Data Flow Architecture

```
UI Layer (Screens/Widgets)
    ↓
Service Layer (Services)
    ↓
Data Layer (Hive + Google Sheets)
```

- **Screens** call **Services** for business logic
- **Services** manage **Hive** (local) and **Google Sheets** (remote)
- **CentralizedDataService** coordinates data sources (Sheets primary, Hive fallback)
- **BackgroundSyncService** handles automatic synchronization
