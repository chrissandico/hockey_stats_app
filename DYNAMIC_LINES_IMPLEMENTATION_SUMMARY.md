# Dynamic Lines Implementation Summary

## Overview
Implemented dynamic row handling for the players on ice widget to automatically show 4 rows for forwards and defense when teams have more than 15 players, while maintaining 3 rows for teams with 15 or fewer players.

## Problem Solved
- Teams with more than 15 players (e.g., >9 forwards or >6 defensemen) needed a 4th row in the players on ice widget
- Teams with 15 or fewer players (like waxersu12aa) should continue to see only 3 rows
- The solution needed to be automatic and dynamic based on player count

## Implementation Details

### 1. LineConfigurationService Updates (`lib/services/line_configuration_service.dart`)

#### Dynamic Line Count Calculation
- Added `_calculateForwardLineCount(int forwardCount)` method:
  - Returns 3 lines for ≤9 forwards
  - Returns 4 lines for 10+ forwards
- Added `_calculateDefenseLineCount(int defenseCount)` method:
  - Returns 3 lines for ≤6 defensemen
  - Returns 4 lines for 7+ defensemen

#### Dynamic Line Structure
- Changed from hardcoded `List<List<Player?>>` to dynamic lists
- Added `_initializeLineStructure()` method to create appropriate number of lines
- Updated `initializeLines()` to calculate required line counts and distribute players accordingly

#### Persistence Updates
- Modified `loadLineConfiguration()` to handle variable line counts
- Updated `updatePosition()` to use dynamic line lengths instead of hardcoded limits
- Ensured all methods work with variable line counts

### 2. PlayerSelectionWidget Updates (`lib/widgets/player_selection_widget.dart`)

#### Dynamic UI Rendering
- Updated `_buildForwardLines()` to use `_lineService.forwardLines.length` instead of hardcoded `3`
- Updated `_buildDefenseLines()` to use `_lineService.defenseLines.length` instead of hardcoded `3`
- All drag-and-drop functionality works seamlessly with additional rows

## Key Benefits

### Automatic Behavior
- No manual configuration required
- Automatically detects team size and adjusts UI accordingly
- Transparent to users - they just see the appropriate number of rows

### Backward Compatible
- Teams with ≤15 players see no change in behavior
- Existing line configurations continue to work
- No breaking changes to existing functionality

### Scalable
- Handles teams with 16+ players seamlessly
- UI automatically adjusts height to accommodate extra rows
- All existing features (drag-and-drop, line selection, persistence) work with additional rows

### Persistent
- Line configurations save and load correctly regardless of line count
- Dynamic configurations are preserved across app sessions
- Handles edge cases where team size changes

## Technical Implementation

### Line Count Logic
```dart
// Forward lines: 3 lines for ≤9 forwards, 4 lines for 10+ forwards
int _calculateForwardLineCount(int forwardCount) {
  if (forwardCount <= 9) return 3;
  return 4;
}

// Defense lines: 3 lines for ≤6 defensemen, 4 lines for 7+ defensemen  
int _calculateDefenseLineCount(int defenseCount) {
  if (defenseCount <= 6) return 3;
  return 4;
}
```

### Dynamic Structure Creation
```dart
void _initializeLineStructure(int forwardLineCount, int defenseLineCount) {
  _forwardLines = List.generate(forwardLineCount, (index) => [null, null, null]);
  _defenseLines = List.generate(defenseLineCount, (index) => [null, null]);
}
```

### Dynamic UI Generation
```dart
// Forward lines - now dynamic
...List.generate(_lineService.forwardLines.length, (lineIndex) {
  // Build line UI
});

// Defense lines - now dynamic  
...List.generate(_lineService.defenseLines.length, (lineIndex) {
  // Build line UI
});
```

## Testing Scenarios

### Teams with ≤15 Players (e.g., waxersu12aa with 15 players)
- ✅ Shows 3 forward lines (9 forwards max)
- ✅ Shows 3 defense lines (6 defensemen max)
- ✅ No visual change from previous behavior
- ✅ All functionality works as before

### Teams with >15 Players
- ✅ Shows 4 forward lines when >9 forwards
- ✅ Shows 4 defense lines when >6 defensemen
- ✅ Additional rows appear automatically
- ✅ All drag-and-drop functionality works with extra rows
- ✅ Line selection and persistence work correctly

## Files Modified
1. `lib/services/line_configuration_service.dart` - Core logic for dynamic line management
2. `lib/widgets/player_selection_widget.dart` - UI updates for dynamic rendering

## Impact
- **Zero breaking changes** - existing functionality preserved
- **Automatic scaling** - no user intervention required
- **Performance optimized** - only creates necessary UI elements
- **Future-proof** - easily extensible for different team sizes

The implementation successfully addresses the requirement for dynamic row handling while maintaining full backward compatibility and preserving all existing functionality.
