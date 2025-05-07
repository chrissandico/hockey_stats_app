# How to Run the Hockey Stats App

Follow these steps to run the app and see the implemented features:

## Prerequisites

Make sure you have Flutter installed and set up on your system. If not, follow the [Flutter installation guide](https://flutter.dev/docs/get-started/install).

## Running the App

1. Open a terminal in the project root directory (`hockey_stats_app`)

2. Run the following command to ensure all dependencies are installed:
   ```
   flutter pub get
   ```

3. Run the app on your preferred device:
   - For Chrome:
     ```
     flutter run -d chrome
     ```
   - For Android emulator/device:
     ```
     flutter run -d android
     ```
   - For iOS simulator/device:
     ```
     flutter run -d ios
     ```

## Testing the New Features

### Period Selection UI

1. Launch the app and select a game from the Game Selection screen
2. On the Log Stats screen, notice the period selector buttons (P1, P2, P3, OT)
3. Click on different period buttons to change the current period
4. Notice the period indicator in the app bar and below the period selector
5. Navigate to Log Shot or Log Penalty screen and observe that the selected period is carried over
6. Use the period change buttons in these screens to change periods
7. After logging a shot or penalty, notice that you return to the Log Stats screen with the period preserved

### Game Details Display

1. On the Log Stats screen, observe the enhanced game details card
2. Notice the formatted date, opponent name, and location (if available)
3. See how the information is organized with icons and proper spacing
4. If you select different games, observe how the details update accordingly

### Team Logos

1. On the Log Stats screen, observe the team logos in the game details section
2. Navigate to the Log Shot screen and notice the enhanced team selection UI with logos
3. Select different teams and observe how the UI updates

## Customizing Team Logos

To add custom team logos, refer to the `LOGO_INSTRUCTIONS.md` file for detailed instructions.

## Implementation Details

For a complete summary of the implemented features and technical details, refer to the `IMPLEMENTATION_SUMMARY.md` file.

## Troubleshooting

If you encounter any issues:

1. Make sure all dependencies are installed:
   ```
   flutter pub get
   ```

2. Clean the project and rebuild:
   ```
   flutter clean
   flutter pub get
   flutter run
   ```

3. Check the Flutter doctor for any system issues:
   ```
   flutter doctor
   ```

4. If you see rendering issues in the UI, try running on a different device or simulator
