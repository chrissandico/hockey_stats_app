# Offline-First Hockey Stats Tracker ("The Shift")

*The Shift* is a mobile application built with Flutter designed to track live hockey game statistics offline and synchronize them seamlessly with Google Sheets.

## Project Goal

To enable coaches, team managers, and stat keepers to easily record hockey game events (Shots, Goals, Penalties, Line Configurations, and Goalie Stats) on a mobile device—even without an internet connection—and reliably sync this data to a team Google Sheet for analysis, sharing, and record-keeping.

## Architecture

* **Client:** Flutter Mobile Application (Android & iOS)
* **Client Local Storage:** Hive Embedded NoSQL Database (Offline-first architecture)
* **Cloud Backend:** Google Sheets Document (Centralized team database)
* **Integration Mechanism:** Google Sheets API (via Flutter `googleapis` & `googleapis_auth` packages)
* **Authentication:** Google OAuth 2.0 User Sign-In & Google Service Account support
* **Core Operational Logic:** Client-side Background Synchronization Service

---

## Comprehensive Feature List

### 🏒 Game Management & Selection
* **Game Creation & Editing:** Add and manage games with opponent details, date/time, venue location, and game type (Regular Season, Exhibition, Tournament).
* **Game Filtering & Search:** Easily filter games by status or game type and search by opponent.

### 👥 Team & Player Roster Management
* **Multi-Team Authentication:** Support for multi-team access with encrypted team passwords stored via `flutter_secure_storage`.
* **Attendance Tracking:** Mark player attendance (present, absent) prior to or during a game. Absent players are clearly styled but remain selectable if needed.
* **Line Configurations & Persistence:** Set up forward lines and defensive pairings with line persistence across periods and games.

### 🎯 Offline-First Stat Logging
* **Log Shots & Goals:** Record shots and goals with primary shooter, optional 1st and 2nd assists, and players on ice.
* **Period Preserving UI:** Easily switch periods (P1, P2, P3, OT) with the selected period persisting across shot, goal, and penalty logging screens.
* **Goal Situations:** Tag goals with situation types (Even Strength, Power Play, Short Handed, Empty Net).
* **Log Penalties:** Track penalized players, penalty type, and duration.
* **Automatic Selection Reset:** Player selections automatically reset after logging an event to streamline sequential tracking.

### 📊 Live Analytics & Summaries
* **Score Summary Header:** Real-time period-by-period score tracking for both teams.
* **Goalie Statistics Widget:** Track saves, goals against, save percentage, and minutes played.
* **Event Management:** Review, edit, or delete logged events directly within the app (`screens/edit_shot_list_screen.dart`).

### 🔄 Sync & Connectivity
* **Background Sync Service:** Automatically syncs events to Google Sheets when connectivity is restored.
* **Connectivity Indicator:** Real-time online/offline status bar displaying sync progress and unsynced event counts.
* **Unsynced Events Screen:** View, inspect, and manually trigger sync for offline events.
* **Duplicate Event Prevention:** Robust deduplication logic ensures events are never duplicated in Google Sheets.

### 📄 Export & Sharing
* **PDF Score Sheet Generation:** Generate formatted PDF game summary reports.
* **Native Sharing & Emailing:** Share PDF score sheets or game summaries via system share dialogs or direct email.

---

## Data Model

The application manages data using the following core Hive entities:

* **Player:** ID, Jersey Number, Name, Team ID, Position.
* **Game:** ID, Date, Opponent, Location, Game Type, Team ID.
* **Team:** ID, Name, Logo Information (`assets/data/team_logos.json`), Team Colors.
* **GameEvent:**
  * *Core fields:* Event ID, Game ID, Timestamp, Period, Event Type (`SHOT`, `GOAL`, `PENALTY`), Team ID.
  * *Player fields:* Primary Player ID (shooter/penalized player), Assist 1 Player ID, Assist 2 Player ID.
  * *Details:* IsGoal, PenaltyType, PenaltyDuration, GoalSituation.
  * *Sync metadata:* `isSynced` boolean flag and timestamp.

---

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd hockey_stats_app
   ```
2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```
3. **Set up Google Sheets:**
   * Follow the configuration steps in `GOOGLE_SHEETS_SETUP.md`.
4. **Run the app:**
   * On an Android device or emulator:
     ```bash
     flutter run
     ```

---

## Project Documentation & Guides

* 📘 [NEW_USER_GUIDE.md](file:///C:/Users/chris/OneDrive/Apps/hockey_stats_app/NEW_USER_GUIDE.md) — Step-by-step onboarding guide for stat keepers and team members.
* 🚀 [HOW_TO_RUN.md](file:///C:/Users/chris/OneDrive/Apps/hockey_stats_app/HOW_TO_RUN.md) — Build and launch instructions across platforms.
* 📊 [GOOGLE_SHEETS_SETUP.md](file:///C:/Users/chris/OneDrive/Apps/hockey_stats_app/GOOGLE_SHEETS_SETUP.md) — Google Sheets structure & API setup guide.
* 👥 [MULTI_TEAM_SETUP.md](file:///C:/Users/chris/OneDrive/Apps/hockey_stats_app/MULTI_TEAM_SETUP.md) — Configuration guide for multi-team access.
* 🛠️ [ADMIN_GUIDE.md](file:///C:/Users/chris/OneDrive/Apps/hockey_stats_app/ADMIN_GUIDE.md) — Administrative instructions for Google Cloud Console OAuth setup.
* 🎨 [LOGO_INSTRUCTIONS.md](file:///C:/Users/chris/OneDrive/Apps/hockey_stats_app/LOGO_INSTRUCTIONS.md) — Custom team logo setup guide.
