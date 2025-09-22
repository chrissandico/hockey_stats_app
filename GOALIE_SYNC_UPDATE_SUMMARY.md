# Goalie On Ice Sync Update Summary

## Overview
Updated the `SheetsService` to properly sync the `goalieOnIceId` field with Google Sheets column O.

## Changes Made

### 1. Updated `syncGameEvent()` method
- Added `event.goalieOnIceId ?? ''` to the values array
- Now syncs goalie information when creating new events

### 2. Updated `updateEventInSheet()` method  
- Added `event.goalieOnIceId ?? ''` to the values array
- Changed range from `A$rowIndex:N$rowIndex` to `A$rowIndex:O$rowIndex`
- Now syncs goalie information when updating existing events

### 3. Updated `fetchEvents()` method
- Changed range from `A2:N` to `A2:O` to include column O
- Added parsing logic for goalie field (column index 14)
- Added `goalieOnIceId: goalieOnIceId` to GameEvent constructor
- Now reads goalie information from Google Sheets

### 4. Updated `_syncGameEventWithRetry()` method
- Added `event.goalieOnIceId ?? ''` to the values array
- Now includes goalie information in retry sync operations

## Database Structure

### Local Storage (Hive)
- **Table:** `GameEvent` 
- **Field:** `goalieOnIceId` (String, nullable)
- **Usage:** Stores the player ID of the goalie on ice during the event

### Google Sheets
- **Sheet:** Events
- **Column:** O (GoalieOnIceId)
- **Data:** Player ID of goalie on ice, empty string if none

## Data Flow

### When Logging Shots/Goals
1. User selects goalie in the shot logging screen
2. `goalieOnIceId` is set to the selected goalie's player ID
3. Event is saved locally with goalie information
4. Event is synced to Google Sheets including goalie data in column O

### When Fetching from Google Sheets
1. Data is fetched from range A2:O (including goalie column)
2. Column O (index 14) is parsed as `goalieOnIceId`
3. GameEvent objects are created with goalie information
4. Local database is updated with complete data

## Statistics Impact

The goalie statistics in `StatsService` already use the `goalieOnIceId` field:
- **Shots Against:** Counts shots where `event.goalieOnIceId == goalie.id`
- **Goals Against:** Counts goals where `event.goalieOnIceId == goalie.id`  
- **Saves:** Calculated as shots against minus goals against
- **Save Percentage:** Calculated as saves divided by shots against
- **Games Played:** Counts unique games where goalie appeared

## Benefits

✅ **Complete Data Synchronization:** All goalie assignments are now preserved in Google Sheets
✅ **Cross-Platform Consistency:** Goalie statistics work the same locally and from Google Sheets data
✅ **Data Recovery:** If local data is lost, goalie assignments can be fully restored
✅ **Reporting Capability:** Full dataset available for analysis and reporting
✅ **Backward Compatibility:** Handles existing events without goalie data gracefully

## Testing Recommendations

1. **Create New Events:** Log shots/goals with goalie selected and verify sync to Google Sheets
2. **Update Existing Events:** Edit existing events and verify goalie data syncs properly  
3. **Fetch from Sheets:** Clear local data and sync from Google Sheets to verify goalie data loads
4. **Statistics Verification:** Check that goalie statistics calculate correctly with synced data
5. **Empty Data Handling:** Verify that events without goalie data handle gracefully

## Next Steps

The implementation is complete and ready for testing. All sync operations now include the goalie field, ensuring complete data integrity between local storage and Google Sheets.
