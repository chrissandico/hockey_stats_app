# Technology Stack

## Framework & Language

- **Flutter SDK**: Cross-platform mobile framework (Dart 3.7.2+)
- **Target Platforms**: Android (6.0+), iOS (13.0+), Web, Windows, macOS, Linux
- **Current Version**: 1.2.0+3

## Core Dependencies

### Data & State Management
- **hive** (2.0.4): Local NoSQL database for offline storage
- **hive_flutter** (1.1.0): Flutter integration for Hive
- **provider** (6.1.5): State management
- **shared_preferences** (2.2.2): User preferences storage
- **flutter_secure_storage** (9.0.0): Secure credential storage

### Google Services Integration
- **google_sign_in** (6.2.1): OAuth authentication
- **googleapis_auth** (1.4.1): Google API authentication
- **googleapis** (12.0.0): Direct Google API access
- **extension_google_sign_in_as_googleapis_auth** (2.0.13): Auth bridge
- **dart_jsonwebtoken** (2.12.1): JWT token handling for service accounts

### UI & Display
- **data_table_2** (2.5.10): Advanced data tables with frozen columns
- **flutter_svg** (2.0.10): SVG rendering for team logos
- **intl** (0.18.0): Date/time formatting and internationalization

### Export & Sharing
- **pdf** (3.10.7): PDF generation
- **printing** (5.12.0): PDF utilities and preview
- **flutter_email_sender** (6.0.2): Email integration
- **share_plus** (7.2.2): Native sharing capabilities
- **path_provider** (2.1.2): File system access

### Utilities
- **uuid** (4.1.0): Unique ID generation
- **http** (1.1.0): HTTP requests
- **wakelock_plus** (1.2.8): Keep screen awake during tracking

## Build System

### Development Tools
- **build_runner** (2.4.8): Code generation runner
- **hive_generator** (2.0.1): Generates Hive TypeAdapters
- **flutter_lints** (5.0.0): Linting rules
- **flutter_launcher_icons** (0.13.1): App icon generation

### Common Commands

```bash
# Install dependencies
flutter pub get

# Run code generation (for Hive adapters)
flutter pub run build_runner build

# Clean and rebuild
flutter clean
flutter pub get

# Run on specific platform
flutter run -d chrome          # Web
flutter run -d android          # Android
flutter run -d ios              # iOS

# Build release APK (Android)
flutter build apk --release

# Build signed APK with keystore
flutter build apk --release --target-platform android-arm64

# Check for issues
flutter doctor

# Analyze code
flutter analyze
```

## Architecture Patterns

### Data Layer
- **Hive TypeAdapters**: Generated code for model serialization
- **Migration Manager**: Handles schema migrations (see `HiveMigrationManager`)
- **Service Account Auth**: JWT-based authentication for Google Sheets

### Service Layer
- **CentralizedDataService**: Single source of truth pattern (Google Sheets primary, local fallback)
- **BackgroundSyncService**: Automatic background synchronization
- **ConnectivityService**: Network status monitoring
- **MemoryCacheService**: In-memory caching for performance
- **SheetsService**: Google Sheets API integration

### State Management
- **Provider**: Dependency injection and state propagation
- **Hive Boxes**: Reactive local storage

## Code Generation

Models use Hive code generation. After modifying models in `lib/models/`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Platform-Specific Configuration

### Android
- **Min SDK**: 21 (Android 5.0)
- **Build**: Gradle with Kotlin DSL
- **Signing**: Keystore at `android/hockey_stats_app.keystore`
- **Config**: `android/key.properties` for release signing

### iOS
- **Min Version**: iOS 13.0
- **Build**: Xcode project
- **Signing**: Managed through Xcode

## Assets

Assets are declared in `pubspec.yaml`:
- `assets/logos/`: Team logos (PNG/SVG)
- `assets/data/`: JSON configuration files (team_logos.json)
- `assets/config/`: Service account credentials

## Testing

```bash
# Run tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

## Performance Considerations

- **Memory Cache**: 2-minute cache for Google Sheets data to reduce API calls
- **Lazy Loading**: Player selection uses efficient filtering
- **Background Sync**: Non-blocking synchronization
- **Wakelock**: Prevents screen sleep during active stat tracking
