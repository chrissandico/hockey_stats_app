# Player Selection Persistence Fix Summary

## Issue Description
When navigating from the log stats screen to the log goal screen, all players except the goalie were persisting correctly. The goalie selection was being lost during navigation.

## Root Cause Analysis
The issue was in the **LogGoalScreen** constructor and initialization:

1. **LogGoalScreen constructor** did not accept a `selectedGoalie` parameter
2. **Navigation call** in LogStatsScreen was not passing the selected goalie
3. **Goalie initialization logic** in LogGoalScreen was always defaulting to the first goalie when none was explicitly set, overriding any previous selection

## Solution Implemented

### 1. Modified LogGoalScreen Constructor
**File:** `lib/screens/log_goal_screen.dart`
- Added `selectedGoalie` parameter to the constructor
- Updated constructor to accept the goalie selection from the previous screen

```dart
class LogGoalScreen extends StatefulWidget {
  final String gameId;
  final int period;
  final String teamId;
  final String? eventIdToEdit;
  final List<Player>? playersOnIce;
  final Player? goalScorer;
  final Player? assist1;
  final Player? assist2;
  final Player? selectedGoalie; // NEW PARAMETER

  const LogGoalScreen({
    super.key, 
    required this.gameId,
    required this.period,
    required this.teamId,
    this.eventIdToEdit,
    this.playersOnIce,
    this.goalScorer,
    this.assist1,
    this.assist2,
    this.selectedGoalie, // NEW PARAMETER
  });
```

### 2. Updated Goalie Initialization Logic
**File:** `lib/screens/log_goal_screen.dart`
- Modified `_loadPlayers()` method to prioritize the passed goalie selection
- Only falls back to default goalie if no goalie was passed from the previous screen

```dart
void _loadPlayers() {
  // ... existing code ...
  
  // Use passed goalie from log stats screen, or set default if none passed and none selected
  if (widget.selectedGoalie != null) {
    _selectedGoalie = widget.selectedGoalie;
  } else if (_goalies.isNotEmpty && _selectedGoalie == null) {
    _selectedGoalie = _goalies.first;
  }
  
  // ... rest of method ...
}
```

### 3. Updated Navigation Call
**File:** `lib/screens/log_stats_screen.dart`
- Modified the navigation call to LogGoalScreen to pass the selected goalie
- Added `selectedGoalie: _selectedGoalie` parameter to the navigation

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => LogGoalScreen(
      gameId: widget.gameId,
      period: _selectedPeriod,
      teamId: widget.teamId,
      playersOnIce: _selectedPlayersOnIce,
      goalScorer: _selectedGoalScorer,
      assist1: _selectedAssist,
      assist2: _selectedAssist2,
      selectedGoalie: _selectedGoalie, // NEW PARAMETER
    ),
  ),
)
```

## Result
Now when navigating from the log stats screen to the log goal screen:
- ✅ All selected players on ice persist correctly
- ✅ Goal scorer selection persists correctly  
- ✅ Assist selections persist correctly
- ✅ **Goalie selection now persists correctly** (FIXED)

## Files Modified
1. `lib/screens/log_goal_screen.dart` - Added goalie parameter and updated initialization logic
2. `lib/screens/log_stats_screen.dart` - Updated navigation call to pass selected goalie

## Testing Recommendations
1. Select players on ice and a goalie in the log stats screen
2. Navigate to the log goal screen
3. Verify that all selections (including the goalie) are maintained
4. Test with different goalie selections to ensure proper persistence
5. Test edge cases like no goalie selected (should fall back to default behavior)

The fix ensures complete player selection persistence between screens while maintaining backward compatibility with existing functionality.
