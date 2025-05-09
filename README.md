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
*   **Log Shots:** Record shot events, including whether it was a goal, who the shooter was, optional assists, and players on ice for goals. All data entry functions fully offline.
*   **Log Penalties:** Record penalty events, including the penalized player, penalty type, and duration. All data entry functions fully offline.
*   **View Local Stats:** Review events logged for the current game and view basic statistics based on locally stored data.
*   **Period Selection:** Users can select the current period (P1, P2, P3, OT) for tracking shots and penalties, with the selected period persisting across relevant screens and clearly indicated in the UI.
*   **Enhanced Game Details Display:** Game information on the stats tracking screen is presented in an improved card-based layout, featuring team logos, informational icons, and better data formatting.
*   **Team Logo Integration:** Team logos are displayed in key areas like game details and team selection, enhancing visual appeal. Logos are managed via a JSON configuration (`assets/data/team_logos.json`) and a dedicated utility (`lib/utils/team_utils.dart`), also supporting team-specific colors.

## Planned Features (from Requirements Document)

*   **Offline Data Entry:** All data entry (logging shots and penalties) will function fully offline, with data stored in a local Hive database.
*   **Data Synchronization:** Automatically synchronize unsynced game event data from the local database to a designated Google Sheet when network connectivity is available.
*   **Initial Data Sync:** On first launch or user request, synchronize Roster and Game data from Google Sheets to the local database.
*   **Robust Synchronization Service:** Implement logic for monitoring network connectivity, identifying unsynced data, formatting data for Google Sheets, handling API errors, retries, and updating sync status.
*   **Detailed Data Model:** Implementation of data models for Players, Games, and GameEvents to manage structured data locally and for synchronization.
*   **Enhanced Plus/Minus Tracking:** Improve the user interface for selecting players on ice, add line combination presets, and provide visual analytics for plus/minus statistics.

## Getting Started

*(Add installation and setup instructions here once available)*

## Data Model

The application manages data based on the following entities:

*   **Player:** Stores player information (jersey number, name).
*   **Game:** Stores game details (date, opponent, location).
*   **Team:** Stores team data including name, logo information (from `assets/data/team_logos.json`), and colors.
*   **GameEvent:** Records individual game events (shots, penalties) with associated details, linked to a specific game and player(s). Includes a sync status flag.

## Technical Details

*   Built with the Flutter SDK.
*   Utilizes a local database (Hive) for offline data persistence.
*   Integrates with the Google Sheets API for cloud synchronization.
*   Includes a Synchronization Service to manage the offline-first data flow.
*   Manages team logos and colors through a JSON configuration file (`assets/data/team_logos.json`) and the `TeamUtils` utility class (`lib/utils/team_utils.dart`).
*   Assets (logos, data files) are declared in `pubspec.yaml`.
*   Key UI enhancements include period selection across stat logging screens and an improved game details display.
