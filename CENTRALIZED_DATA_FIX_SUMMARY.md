# Centralized Data Service Implementation - Fix for Missing Goals Issue

## Problem Summary
The waxersu12aa team was missing a goal in the log stats screen and PDF reports, even though Google Sheets contained three goals but the app only showed two. This was caused by the app using **local Hive database cache** instead of always pulling from **Google Sheets as the source of truth**.

## Root Cause Analysis
1. **Multiple Data Sources**: The app had both local Hive storage and Google Sheets, but wasn't properly centralized
2. **Cache Inconsistency**: Local data could become out of sync with Google Sheets
3. **No Real-time Refresh**: Stats calculations used stale local data instead of fresh Google Sheets data
4. **Fragmented Data Access**: Different screens accessed data differently, leading to inconsistencies

## Solution Implemented

### 1. Created Centralized Data Service (`lib/services/centralized_data_service.dart`)
- **Single Source of Truth**: All data access now goes through this service
- **Google Sheets Priority**: Always attempts to fetch from Google Sheets first
- **Smart Caching**: 2-minute cache to avoid excessive API calls while ensuring freshness
- **Fallback Strategy**: Uses local data only when Google Sheets is unavailable
- **Force Refresh**: Ability to bypass cache and get the latest data

Key Features:
```dart
// Get current game events with Google Sheets priority
Future<List<GameEvent>> getCurrentGameEvents(String gameId, {bool forceRefresh = false})

// Calculate score using fresh Google Sheets data
Future<Map<String, int>> calculateCurrentScore(String gameId, String teamId, {bool forceRefresh = false})

// Force refresh all data from Google Sheets
Future<bool> forceRefreshFromSheets()
```

### 2. Updated Log Stats Screen (`lib/screens/log_stats_screen.dart`)
- **Removed Local Score Calculation**: Eliminated the old `_calculateScore()` function
- **Integrated Centralized Service**: Now uses `CentralizedDataService` for all score calculations
- **Real-time Updates**: Score display now uses `FutureBuilder` to fetch fresh data
- **Force Refresh**: `_refreshScore()` method now forces fresh data from Google Sheets

### 3. Updated View Stats Screen (`lib/screens/view_stats_screen.dart`)
- **Added Refresh Button**: Users can manually refresh from Google Sheets
- **Real-time Data**: All stats tables now use fresh Google Sheets data
- **Loading Indicators**: Shows when data is being refreshed
- **Automatic Refresh**: Loads fresh data when screen opens

### 4. Updated PDF Service (`lib/services/pdf_service.dart`)
- **Latest Data Option**: Added `useLatestData` parameter (defaults to true)
- **Fresh Data Fetching**: PDFs now generate using the most current Google Sheets data
- **Fallback Protection**: Uses provided data if Google Sheets fetch fails

## Key Benefits

### ✅ **Data Consistency**
- All screens now show the same data from Google Sheets
- No more discrepancies between local cache and remote data
- Missing goals and stats are now properly displayed

### ✅ **Real-time Accuracy**
- Stats are always current and reflect the latest Google Sheets data
- Users see updates immediately after data changes
- No need to manually sync to see current stats

### ✅ **Centralized Architecture**
- Single point of data access makes the system more maintainable
- Consistent error handling and retry logic
- Easier to debug data-related issues

### ✅ **Performance Optimized**
- Smart caching reduces unnecessary API calls
- 2-minute cache window balances freshness with performance
- Fallback to local data ensures app works offline

### ✅ **User Experience**
- Manual refresh options for immediate updates
- Loading indicators show when data is being fetched
- Automatic background refresh keeps data current

## Technical Implementation Details

### Data Flow (Before)
```
App Screen → Local Hive Database → Display (potentially stale data)
```

### Data Flow (After)
```
App Screen → CentralizedDataService → Google Sheets (fresh data) → Display
                                   ↓ (if unavailable)
                                   Local Hive Database (fallback)
```

### Cache Strategy
- **Cache Duration**: 2 minutes for optimal balance
- **Cache Invalidation**: Force refresh bypasses cache
- **Cache Updates**: Fresh data automatically updates local cache
- **Offline Support**: Local data available when Google Sheets unavailable

## Files Modified
1. `lib/services/centralized_data_service.dart` - **NEW** centralized data service
2. `lib/screens/log_stats_screen.dart` - Updated to use centralized service
3. `lib/screens/view_stats_screen.dart` - Updated to use centralized service  
4. `lib/services/pdf_service.dart` - Updated to use latest data for PDFs

## Testing Recommendations
1. **Verify Missing Goals**: Check that waxersu12aa team now shows all 3 goals
2. **Test Data Consistency**: Ensure all screens show the same stats
3. **Test Refresh Functionality**: Verify manual refresh buttons work
4. **Test Offline Mode**: Ensure app works when Google Sheets unavailable
5. **Test PDF Generation**: Verify PDFs contain the latest data

## Future Enhancements
- Add data validation to detect and warn about inconsistencies
- Implement background sync scheduling
- Add conflict resolution for simultaneous edits
- Consider implementing real-time data streaming

This implementation ensures that **Google Sheets is always the source of truth** and that all statistics calculations are centralized and consistent across the entire application.
