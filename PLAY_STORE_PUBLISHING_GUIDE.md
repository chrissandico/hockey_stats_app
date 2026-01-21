# Google Play Store Publishing Guide

This guide walks you through publishing the Hockey Stats App to the Google Play Store.

## Current Status

✅ **Already Configured:**
- App signing with keystore
- Release build configuration
- ProGuard/R8 optimization enabled
- Application ID: `io.professormeta.hockeystatsapp`
- Current version: 1.2.0 (build 3)

## Prerequisites Checklist

Before you begin, ensure you have:

- [ ] Google Play Console account ($25 one-time registration fee)
- [ ] Keystore file and credentials (you have: `android/hockey_stats_app.keystore`)
- [ ] App icon and feature graphic
- [ ] Screenshots for different device sizes
- [ ] Privacy policy URL (required for apps requesting permissions)
- [ ] App description and marketing materials

## Step 1: Prepare Your App for Release

### 1.1 Update Version Information

Your current version is `1.2.0+3`. For Play Store submission:

```yaml
# In pubspec.yaml
version: 1.2.0+3  # Format: major.minor.patch+buildNumber
```

- **versionName**: 1.2.0 (user-facing version)
- **versionCode**: 3 (internal build number, must increment with each release)

### 1.2 Review App Permissions

Your app currently requests:
- `INTERNET` - Required for Google Sheets sync

**Action Required:** Create a privacy policy explaining:
- What data you collect (game stats, player info)
- How you use it (stored in Google Sheets)
- Google Sign-In usage
- Data retention and deletion policies

### 1.3 Update App Description

Edit `pubspec.yaml` to have a proper description:

```yaml
description: "Offline-first hockey statistics tracker with Google Sheets synchronization. Track shots, goals, penalties, and player stats during live games."
```

### 1.4 Test Release Build

Build and test the release APK:

```bash
# Build release APK
flutter build apk --release

# Or build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

The output will be at:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

**Important:** Use App Bundle (.aab) for Play Store - it's required for new apps and provides smaller downloads.

## Step 2: Create Google Play Console Account

1. Go to [Google Play Console](https://play.google.com/console)
2. Sign in with your Google account
3. Pay the $25 one-time registration fee
4. Complete the account setup (developer name, contact info)
5. Accept the Developer Distribution Agreement

## Step 3: Create Your App in Play Console

### 3.1 Create New App

1. Click "Create app" in Play Console
2. Fill in the details:
   - **App name**: "Hockey Stats Tracker" (or your preferred name)
   - **Default language**: English (United States)
   - **App or game**: App
   - **Free or paid**: Free
3. Accept declarations and create app

### 3.2 Set Up App Content

Complete all required sections in the left sidebar:

#### Privacy Policy
- **Required**: Yes (you use Google Sign-In and internet permissions)
- Host your privacy policy online (GitHub Pages, your website, etc.)
- Enter the URL in Play Console

#### App Access
- Explain if your app requires login
- Provide test credentials if needed for review

#### Ads
- Declare if your app contains ads (currently: No)

#### Content Ratings
1. Click "Start questionnaire"
2. Select category: "Utility, Productivity, Communication, or Other"
3. Answer questions about content
4. Submit for rating (free, takes a few minutes)

#### Target Audience
- Select age groups (likely "18 and older" for sports stats)
- Declare if app is designed for children (No)

#### News Apps
- Declare if this is a news app (No)

#### Data Safety
**Critical Section** - Declare what data you collect:

**Data Collection:**
- User account info (email from Google Sign-In)
- App activity (game stats, player data)
- Device or other IDs (for authentication)

**Data Usage:**
- App functionality
- Analytics (if applicable)

**Data Sharing:**
- Shared with Google Sheets
- Not sold to third parties

**Security Practices:**
- Data encrypted in transit (HTTPS)
- Users can request data deletion
- Committed to Google Play Families Policy (if applicable)

## Step 4: Prepare Store Listing

### 4.1 Main Store Listing

Navigate to "Main store listing" and fill in:

#### App Details
- **App name**: Hockey Stats Tracker (max 30 characters)
- **Short description**: (max 80 characters)
  ```
  Track hockey stats offline. Sync with Google Sheets. Real-time collaboration.
  ```
- **Full description**: (max 4000 characters)
  ```
  Hockey Stats Tracker is an offline-first mobile application designed for tracking hockey game statistics in real-time. Perfect for team stat trackers, coaches, and scorekeepers who need reliable data collection during live games.

  KEY FEATURES:
  • Offline-First: Track all stats without internet connection
  • Automatic Sync: Data syncs to Google Sheets when online
  • Multi-Team Support: Manage multiple teams with separate data
  • Real-Time Collaboration: Multiple users can track simultaneously
  • Comprehensive Tracking: Goals, assists, shots, penalties, attendance
  • Line Management: Configure and track player lines
  • Goalie Stats: Track saves, goals against, and save percentage
  • PDF Reports: Generate and share game reports
  • Email Integration: Send stats directly from the app

  PERFECT FOR:
  • Team stat trackers and scorekeepers
  • Coaches needing real-time game data
  • Team administrators managing multiple teams
  • Anyone tracking hockey statistics during live games

  HOW IT WORKS:
  1. Sign in with your Google account
  2. Select or create a game
  3. Track stats during the game (works offline)
  4. Data automatically syncs to Google Sheets when online
  5. View stats, generate reports, and share with your team

  OFFLINE CAPABILITY:
  All stat tracking works without internet. Your data is stored locally and automatically syncs when you're back online.

  GOOGLE SHEETS INTEGRATION:
  Your data is stored in Google Sheets for easy analysis, reporting, and sharing with your team.

  PRIVACY & SECURITY:
  • Your data is stored securely in your Google Sheets
  • We don't sell or share your data with third parties
  • All data transmission is encrypted
  ```

#### Graphics Assets (Required)

**App Icon:**
- Already configured: `assets/logos/waxers_logo.png`
- Size: 512x512 px
- Format: PNG (32-bit)

**Feature Graphic:**
- Size: 1024x500 px
- Format: PNG or JPEG
- **Action Required**: Create this graphic (app name + key visual)

**Screenshots (Required):**
You need at least 2 screenshots for each supported device type:

- **Phone screenshots**: 
  - Min 2, max 8
  - Recommended: 1080x1920 px (portrait) or 1920x1080 px (landscape)
  - Show key features: game selection, stat tracking, stats view

- **7-inch tablet screenshots** (optional but recommended):
  - Same requirements as phone

- **10-inch tablet screenshots** (optional):
  - Same requirements as phone

**Action Required**: Take screenshots of:
1. Game selection screen
2. Stat tracking screen (log stats)
3. Shot/goal logging
4. Statistics view
5. Player selection
6. Settings/sync screen

#### Contact Details
- **Email**: Your support email
- **Phone** (optional): Support phone number
- **Website** (optional): Your website or GitHub repo

#### Category
- **App category**: Sports
- **Tags** (optional): hockey, statistics, sports tracking, offline

## Step 5: Set Up Release

### 5.1 Choose Release Track

Play Console offers multiple tracks:
- **Internal testing**: Up to 100 testers (fast review)
- **Closed testing**: Limited testers (fast review)
- **Open testing**: Anyone can join (standard review)
- **Production**: Public release (standard review)

**Recommendation**: Start with **Internal testing** or **Closed testing**

### 5.2 Create Release

1. Go to "Testing" → "Internal testing" (or your chosen track)
2. Click "Create new release"
3. Upload your App Bundle:
   ```bash
   flutter build appbundle --release
   ```
4. Upload: `build/app/outputs/bundle/release/app-release.aab`

### 5.3 Release Notes

Add release notes for version 1.2.0:

```
Initial release of Hockey Stats Tracker

Features:
• Offline-first stat tracking
• Google Sheets synchronization
• Multi-team support
• Track goals, assists, shots, and penalties
• Player attendance management
• Line configuration
• Goalie statistics
• PDF report generation
• Email and sharing capabilities
```

### 5.4 Review and Roll Out

1. Review all information
2. Click "Review release"
3. Fix any errors or warnings
4. Click "Start rollout to [track name]"

## Step 6: App Review Process

### Timeline
- **Internal/Closed testing**: Usually within hours
- **Production**: 1-7 days (typically 1-3 days)

### What Google Reviews
- App functionality
- Privacy policy compliance
- Content rating accuracy
- Permissions usage
- Metadata accuracy

### Common Rejection Reasons
- Missing or inadequate privacy policy
- Permissions not explained
- Crashes or bugs
- Misleading screenshots or description
- Incomplete store listing

## Step 7: Post-Submission

### Monitor Review Status
- Check Play Console dashboard regularly
- You'll receive email notifications

### If Approved
- App goes live on the selected track
- Share test link with testers (for testing tracks)
- Monitor crash reports and user feedback

### If Rejected
- Review rejection reason carefully
- Fix issues
- Resubmit with explanations

## Step 8: Promote to Production

Once testing is successful:

1. Go to "Testing" → "Promote release"
2. Select "Production"
3. Add production release notes
4. Review and roll out
5. Wait for production review (1-7 days)

## Ongoing Maintenance

### Updating Your App

When releasing updates:

1. Increment version in `pubspec.yaml`:
   ```yaml
   version: 1.2.1+4  # Increment both version and build number
   ```

2. Build new App Bundle:
   ```bash
   flutter build appbundle --release
   ```

3. Create new release in Play Console
4. Upload new AAB
5. Add release notes describing changes
6. Roll out to chosen track

### Version Code Rules
- Must be higher than previous version
- Cannot reuse version codes
- Recommended: increment by 1 for each release

## Quick Command Reference

```bash
# Build release App Bundle (recommended)
flutter build appbundle --release

# Build release APK (for testing)
flutter build apk --release

# Build split APKs by ABI (smaller downloads for testing)
flutter build apk --split-per-abi --release

# Check for issues before building
flutter analyze

# Run tests
flutter test

# Clean build
flutter clean
flutter pub get
flutter build appbundle --release
```

## Troubleshooting

### Build Fails
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build appbundle --release
```

### Signing Issues
- Verify `android/key.properties` exists and has correct values
- Verify keystore file path is correct
- Check keystore password and alias

### Upload Rejected
- Ensure version code is higher than previous
- Check App Bundle is signed correctly
- Verify no duplicate version codes

### Review Rejection
- Read rejection email carefully
- Address all issues mentioned
- Update privacy policy if needed
- Add missing screenshots or descriptions

## Resources

- [Google Play Console](https://play.google.com/console)
- [Play Console Help](https://support.google.com/googleplay/android-developer)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)

## Checklist Before Submission

- [ ] Privacy policy created and hosted
- [ ] App tested in release mode
- [ ] Screenshots taken (minimum 2 for phone)
- [ ] Feature graphic created (1024x500)
- [ ] Store listing completed
- [ ] Content rating obtained
- [ ] Data safety section completed
- [ ] Release notes written
- [ ] App Bundle built and tested
- [ ] All Play Console sections marked complete
- [ ] Test credentials provided (if app requires login)

## Next Steps

1. Create privacy policy (host on GitHub Pages or your website)
2. Take screenshots of your app
3. Create feature graphic
4. Register for Google Play Console
5. Complete store listing
6. Build App Bundle
7. Submit for review

Good luck with your app launch! 🚀
