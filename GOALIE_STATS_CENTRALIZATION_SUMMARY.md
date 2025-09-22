# Goalie Stats Centralization Summary

## Overview
Successfully centralized goalie statistics calculation and display across the hockey stats application to ensure consistency and maintainability.

## Changes Made

### 1. Created Centralized Goalie Stats Widget
**File:** `lib/widgets/goalie_stats_widget.dart` (NEW)

**Features:**
- Reusable widget for displaying goalie statistics consistently
- Configurable options: `showTitle`, `showLegend`, `isLoading`
- Consistent styling with purple theme for goalie stats
- Color-coded save percentages:
  - Green: ≥90% (excellent)
  - Orange: ≥80% (good)
  - Red: >0% (needs improvement)
  - Default: 0% (no data)
- Includes comprehensive legend explaining all abbreviations
- Uses `StatsService.getGoalieStats()` for consistent calculations

### 2. Updated View Stats Screen
**File:** `lib/screens/view_stats_screen.dart`

**Changes:**
- **Fixed spacing issue:** Reduced gap from 32px to 16px between player and goalie stats
- **Replaced inline goalie stats:** Now uses centralized `GoalieStatsWidget`
- **Removed duplicate code:** Eliminated ~100 lines of redundant goalie stats implementation
- **Added import:** `import 'package:hockey_stats_app/widgets/goalie_stats_widget.dart';`

### 3. Enhanced PDF Export Service
**File:** `lib/services/pdf_service.dart`

**Major Updates:**
- **Added goalie stats to PDF exports:** Now includes goalie statistics in left column
- **New method:** `_buildCompactGoalieStats()` for PDF-optimized goalie stats display
- **Updated layout:** Left column now contains both team stats AND goalie stats
- **Compact table format:** Optimized for PDF space constraints with smaller fonts
- **Color-coded sections:** Purple theme for goalie stats matching app UI
- **Comprehensive legend:** Includes abbreviation explanations in PDF

**PDF Layout Structure:**
```
Left Column (30%):           Right Column (70%):
├── Team Statistics         ├── Individual Player Stats
└── Goalie Statistics       └── (Player stats table)
    ├── Stats Table
    └── Legend
```

## Benefits Achieved

### ✅ Consistency
- All screens now display goalie stats identically
- Same calculations, styling, and color coding everywhere
- Unified legend and abbreviations across app and PDF

### ✅ Maintainability  
- Single source of truth for goalie stats display logic
- Changes to goalie stats UI only need to be made in one place
- Reduced code duplication by ~100 lines

### ✅ Enhanced PDF Exports
- PDF exports now include complete game statistics
- Goalie performance data available for sharing and analysis
- Professional layout with proper spacing and organization

### ✅ Improved User Experience
- Fixed spacing issue in view stats screen
- Better visual hierarchy and organization
- Complete statistical picture in all formats

## Technical Implementation

### Goalie Stats Widget API
```dart
GoalieStatsWidget(
  goalies: List<Player>,           // Required: List of goalie players
  gameEvents: List<GameEvent>,     // Required: Game events for calculations
  teamId: String,                  // Required: Team ID for filtering
  isLoading: bool,                 // Optional: Show loading indicator
  showTitle: bool,                 // Optional: Display "Goalie Stats" title
  showLegend: bool,                // Optional: Show abbreviation legend
)
```

### Statistics Calculated
- **SA (Shots Against):** Total shots faced by goalie
- **GA (Goals Against):** Total goals allowed by goalie  
- **SV (Saves):** Calculated as SA - GA
- **SV% (Save Percentage):** Calculated as SV / SA * 100
- **GP (Games Played):** Unique games where goalie appeared

### PDF Integration
- Goalie stats automatically included when goalies exist in player list
- Compact table format optimized for PDF space constraints
- Consistent with app styling using purple theme
- Legend included for clarity in printed/shared documents

## Files Modified
1. **lib/widgets/goalie_stats_widget.dart** - NEW centralized widget
2. **lib/screens/view_stats_screen.dart** - Updated to use widget, fixed spacing
3. **lib/services/pdf_service.dart** - Added goalie stats to PDF exports

## Testing Recommendations
1. **View Stats Screen:** Verify goalie stats display correctly with proper spacing
2. **PDF Export:** Generate PDF and confirm goalie stats appear in left column
3. **Share Functionality:** Test sharing PDFs with complete goalie statistics
4. **Multiple Goalies:** Test with teams having multiple goalies
5. **No Goalies:** Verify graceful handling when no goalies exist
6. **Statistics Accuracy:** Confirm all goalie calculations match expected values

## Future Enhancements
- Consider adding goalie stats to other screens that might benefit
- Potential for additional goalie-specific metrics (GAA, shutouts, etc.)
- Could extend widget for season-long statistics display

The centralization is complete and provides a solid foundation for consistent goalie statistics throughout the application.
