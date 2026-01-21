# Hockey Stats App Setup Guide

This guide provides comprehensive instructions to set up and run the Hockey Stats App.

## 1. Prerequisites

*   **Install Flutter:** Ensure that Flutter is installed and configured on your system. If not, please follow the [official Flutter installation guide](https://flutter.dev/docs/get-started/install).

## 2. Initial App Setup

1.  **Download or Clone the App:** Obtain the application files by downloading or cloning the repository.
2.  **Open a Terminal:** Navigate to the root directory of the project (e.g., `hockey_stats_app`) in your terminal or command prompt.
3.  **Install Dependencies:** Run the following command to fetch all necessary project dependencies:
    ```bash
    flutter pub get
    ```

## 3. Google Sheets Configuration (Essential for Data)

The application relies on Google Sheets for managing player, game, and event data.

1.  **Create a Google Sheet:** Start by creating a new Google Sheet in your Google Drive.
2.  **Set Up Required Sheets:** Inside your Google Sheet, create three individual sheets with the exact names: "Players", "Games", and "Events".

    *   ### "Players" Sheet
        This sheet stores information about the players.

        *   **Column A: ID (Required)**
            *   A unique identifier for each player (e.g., "player_1", "p001").
            *   Must be a non-empty string.
        *   **Column B: Jersey Number (Required)**
            *   The player's jersey number.
            *   Must be a number greater than or equal to 0.
        *   **Column C: Team ID (Optional)**
            *   Identifies which team the player belongs to.
            *   Defaults to "your_team" if left blank. Use "your_team" for your own team's players and distinct identifiers for opponent players.

        **Example "Players" Sheet:**
        ```
        ID          | Jersey Number | Team ID
        player_1    | 4             | your_team
        player_2    | 2             | your_team
        player_3    | 17            | your_team
        opponent_1  | 10            | rivals_team
        ```

    *   ### "Games" Sheet
        This sheet tracks game information.

        *   **Column A: ID (Required)**
            *   A unique identifier for each game (e.g., "game_20231028_vs_rivals").
        *   **Column B: Date (Required)**
            *   The date of the game.
            *   Supported formats: YYYY-MM-DD (e.g., "2023-10-28") or MM/DD/YYYY (e.g., "10/28/2023").
        *   **Column C: Opponent (Required)**
            *   The name of the opponent team.
        *   **Column D: Location (Optional)**
            *   The venue or location where the game is played.

        **Example "Games" Sheet:**
        ```
        ID                      | Date       | Opponent | Location
        game_20231028_rivals    | 2023-10-28 | Rivals   | Home Arena
        game_20231104_chiefs    | 2023-11-04 | Chiefs   | Away Rink
        ```

    *   ### "Events" Sheet
        This sheet is automatically populated by the app as you log shots, penalties, and other game events. **No initial setup is required for this sheet beyond creating it with the correct name.**

    **Important Notes for Google Sheets:**
    *   **Headers:** Ensure Row 1 in both "Players" and "Games" sheets contains headers as shown in the examples. The app starts reading data from Row 2.
    *   **Sheet Names:** Use the exact sheet names: "Players", "Games", and "Events".
    *   **Unique IDs:** All IDs in Column A for "Players" and "Games" must be unique.

## 4. Customizing Team Logos (Optional)

Enhance the app's visual experience by adding custom team logos.

1.  **Prepare Logo Files:**
    *   Obtain or create logo images, preferably in PNG format with transparent backgrounds.
    *   A recommended size is approximately 200x200 pixels.
    *   Name them descriptively (e.g., `my_team_logo.png`, `rivals_logo.png`).
2.  **Add Logos to Project:**
    *   Place your logo image files into the `assets/logos/` directory within the project.
3.  **Update `pubspec.yaml`:**
    *   Open the `pubspec.yaml` file located in the project root.
    *   Ensure the `assets/logos/` and `assets/data/` directories are declared under `flutter:` -> `assets:`. It should look similar to this:
        ```yaml
        flutter:
          uses-material-design: true
          assets:
            - assets/logos/
            - assets/data/
        ```
    *   After saving changes to `pubspec.yaml`, run `flutter pub get` in your terminal again.
4.  **Update Team Logo Database:**
    *   Edit the `assets/data/team_logos.json` file.
    *   Add new entries for your teams, specifying their ID, name, the path to their logo file, and optionally, primary and secondary colors.
    *   **Example entry to add:**
        ```json
        {
          "id": "your_team_id",
          "name": "Your Team Name",
          "logoPath": "assets/logos/your_team_logo.png",
          "primaryColor": "#0044AA",  // Example primary color
          "secondaryColor": "#FFFFFF" // Example secondary color
        }
        ```
        Add this within the `"teams": [...]` array.

## 5. Running the App

Once the setup is complete, you can run the application.

1.  **Choose Your Target Device/Platform:**
2.  **Run the Command:** In your terminal (still in the project root), execute one of the following:
    *   **For Web (Chrome):**
        ```bash
        flutter run -d chrome
        ```
    *   **For Android (Emulator or Connected Device):**
        ```bash
        flutter run -d android
        ```
    *   **For iOS (Simulator or Connected Device):**
        ```bash
        flutter run -d ios
        ```
        (Note: iOS development requires macOS and Xcode.)

## 6. In-App Google Sheets Authentication

*   When you first run the app and attempt to access features that interact with Google Sheets (like selecting a game or viewing players), you will be prompted to sign in with your Google account.
*   Follow the on-screen instructions to authorize the app to access your Google Sheets data.

## 7. Troubleshooting

If you encounter issues:

*   **Dependencies:** Ensure all dependencies are correctly installed by running `flutter pub get`.
*   **Clean Build:** Try cleaning the project and rebuilding:
    ```bash
    flutter clean
    flutter pub get
    flutter run -d <your_target_device>
    ```
*   **Flutter Doctor:** Check your Flutter installation and environment for any issues:
    ```bash
    flutter doctor
    ```
*   **Google Sheets Errors:**
    *   Double-check sheet names ("Players", "Games", "Events").
    *   Verify column headers and required data fields in your "Players" and "Games" sheets.
    *   Ensure you have granted the app the necessary permissions to access your Google Sheet.
*   **Logo Issues:**
    *   Confirm logo file paths in `team_logos.json` are correct and point to files in `assets/logos/`.
    *   Make sure `assets/logos/` is correctly listed in `pubspec.yaml` and you've run `flutter pub get`.

This guide should help you get the Hockey Stats App up and running. Happy tracking!
