# Release Notes

## Bug Fixes

- **Fixed special teams calculations** - Goal situations are now always recorded and counted from our team's perspective ("We have the Power Play" / "We're on the Penalty Kill"), whichever team scores. Short-handed goals against no longer count against the penalty kill, so PK% and the Special Teams Index are correct (e.g. a kill that allows 2 power-play goals in 4 chances now reads 50%, not 25%). Plus/minus on power-play and short-handed goals now follows the standard rule in both the app and the website. Note: special-teams numbers for games logged before this update may change, because older games were recorded in mixed styles.
- **Penalty Kill mode no longer turns on by itself** - Opening the penalty screen and backing out without logging a penalty no longer switches the game to Penalty Kill mode, and the PP/PK mode no longer resets to Even Strength just because a goal was scored.

- **Fixed duplicate events in database** - Events will no longer appear multiple times in Google Sheets
- **Player selections now clear automatically** - After logging a goal or penalty, player selections reset for the next event
- **Fixed goal logging validation** - Goals with fewer than 5 players now require selecting Power Play or Penalty Kill

## Improvements

- **Absent players are now movable** - You can now select absent players if needed (they still show as absent with gray styling)
- **Cleaner goal confirmation dialogs** - Removed unnecessary icons for a simpler interface
- **Game type field added** - You can now set game type (Regular Season, Exhibition, Tournament) when editing games
- **Improved sync reliability** - All events now sync in the background for better performance and consistency
