# New User Guide - Hockey Stats App

Welcome to the Hockey Stats App! This guide will help you get started with tracking stats for the team.

## Prerequisites

Before you begin, ensure you have:
- A Google account (you'll need to be approved as a test user)
- Android 6.0+ or iOS 13.0+ device
- Sufficient storage space (at least 100MB)
- Internet connection (for initial setup and data sync)

## Getting Started

### 1. Getting Access to the App
The app requires two types of access to be set up by the team administrator:

1. **OAuth Test User Access**
   - Send your Google email address to the team administrator
   - Administrator will add you as a test user in the Google Cloud Console
   - This allows you to authenticate with the app
   - Without this, you'll see an "Access blocked" message when trying to sign in

2. **Google Sheet Access**
   - Administrator will share the team's Google Sheet with your email
   - You'll be given "Editor" access to allow recording stats
   - Without this, you'll see a "Permission denied" error after signing in

Both types of access are required to use the app. Wait for confirmation from the administrator that both have been set up before proceeding.

### 2. Installing the App (Sideloading)

#### For Android Users:
1. Enable installation from unknown sources:
   - Go to Settings > Security (or Privacy)
   - Enable "Install from Unknown Sources" or "Install Unknown Apps"
   - If prompted to allow specific app, choose your file manager or browser
2. Install the APK:
   - Locate the APK file you received (usually in Downloads)
   - Tap the APK file to begin installation
   - Tap "Install" when prompted
   - Tap "Done" or "Open" when installation completes

#### For iOS Users:
1. Via TestFlight:
   - Install TestFlight from the App Store
   - Open the TestFlight invitation link you received
   - Follow the prompts to install the app
2. Manual Installation (requires developer):
   - Connect your device to a computer with the app build
   - Trust the developer in Settings > General > Device Management
   - Follow the developer's instructions for installation

### 3. First Launch & Authentication
- When you first open the app, you'll be prompted to sign in with your Google account
- Select the Google account that was approved as a test user
- If you see "Access blocked" message:
  - Verify you're using the approved Google account
  - Contact the administrator to ensure your account was added as a test user
  - Try signing out and signing back in
- Once authenticated successfully, you'll only need to sign in once

### 4. Start Tracking Stats
Once signed in, you can immediately start tracking stats:
- Select a game from the game list
- Use the various tracking options:
  - Log shots and goals
  - Record penalties
  - View current game stats
  - Review previous game statistics

### 5. Important Things to Know

#### Collaborative Tracking
- Multiple people can track stats simultaneously during games
- All data goes to the same team sheet
- Everyone sees the same players, games, and events in real-time
- Changes sync automatically when you have internet connectivity

#### Offline Support
- You can track stats without an internet connection
- The app will store your data locally
- When internet connectivity is restored, the app will automatically sync your data

#### Best Practices
- Make sure you're tracking stats for the correct game
- Verify the period number before logging events
- Double-check player numbers when recording shots or penalties
- If multiple people are tracking, coordinate who is tracking what (e.g., one person for shots, another for penalties)

### 6. Troubleshooting

1. **Installation Issues**
   
   Android:
   - If "Install blocked": Enable installation from unknown sources
   - If "App not installed": Remove any old versions first
   - If "Parse error": Re-download the APK file
   
   iOS:
   - If "Unable to Download App": Ensure you're using TestFlight
   - If "Untrusted Developer": Trust the developer in Settings
   - If TestFlight says "App not available": Request a new invitation

2. **Can't Sign In**
   - Check your internet connection
   - Verify you're using the approved Google account
   - If you see "Access blocked":
     1. Confirm your Google account was added as a test user
     2. Try signing out completely and signing back in
     3. Clear the app's cache and data
     4. Contact the administrator if issues persist

3. **Data Not Syncing**
   - Check your internet connection
   - The app will automatically retry syncing when connection is restored
   - You can continue tracking stats offline

4. **App Not Responding**
   - Close and reopen the app
   - Make sure you have the latest version installed
   - If problems persist, try uninstalling and reinstalling

### 7. Getting Help

If you need assistance:
- Review this guide for basic setup and usage
- Check the GOOGLE_SHEETS_SETUP.md file for detailed information about the data structure
- Contact the team administrator for:
  - Getting approved as a test user
  - Installation issues
  - Authentication problems
  - General app support

Remember: You're contributing to the team's stats tracking effort. When in doubt, it's better to ask for clarification than to log incorrect data.
