# Administrator Guide - Hockey Stats App

This guide explains how to manage test users for the Hockey Stats App.

## Required Access Setup

New users need two types of access to use the app:
1. OAuth test user access (to authenticate with the app)
2. Google Sheet access (to read/write stats data)

### 1. Adding OAuth Test Users

1. Go to the Google Cloud Console:
   - Visit https://console.cloud.google.com
   - Sign in with the developer account (chris.sandico@gmail.com)
   - Select the project for Hockey Stats App

2. Navigate to OAuth consent screen:
   - From the left menu, go to "APIs & Services" > "OAuth consent screen"
   - You should see the app in "Testing" mode

3. Add test users:
   - Scroll down to the "Test users" section
   - Click "ADD USERS"
   - Enter the email addresses of the users who need access
   - You can add up to 100 test users
   - Click "SAVE" to apply the changes

4. Share the Google Sheet:
   - Open the team's Google Sheet in your browser
   - Click the "Share" button in the top-right corner
   - Enter the user's Gmail address
   - Set their access level to "Editor" (required for the app to work)
   - Click "Send" to share the sheet

5. Notify users:
   - Inform users they've been granted both types of access
   - Direct them to the NEW_USER_GUIDE.md for installation instructions
   - Remind them to use the same Google account you added as a test user

## Managing User Access

### Removing Test Users
1. Go to the OAuth consent screen as described above
2. Find the user in the "Test users" list
3. Click the trash icon next to their email
4. Click "SAVE" to apply the changes

### Checking Test User Status
1. Go to the OAuth consent screen
2. The "Test users" section shows all currently approved users
3. You can verify if a specific email is already added

## Common Issues

### User Access Issues

#### "Access Blocked" Error
1. Verify the exact email address they're using
2. Check if it matches what's in the test users list
3. Ask them to completely sign out and sign back in
4. If issues persist, remove and re-add them as a test user

#### "Permission Denied" Error
1. Open the Google Sheet and click "Share"
2. Check if their email is listed with Editor access
3. If not, add them with Editor access
4. If they are listed, try removing and re-adding them
5. Ask them to sign out of the app and sign back in

### Publishing the App

If you need to support more than 100 users or want to remove the test user requirement:
1. Complete the verification form in the OAuth consent screen
2. Provide required documentation:
   - Privacy policy
   - Terms of service
   - Demonstration video
   - Justification for requested scopes
3. Submit for Google verification
4. Once approved, the app will work for any Google account

## Support

For issues with the Google Cloud Console or OAuth configuration:
- Check the [Google Cloud Documentation](https://cloud.google.com/docs)
- Review the [OAuth 2.0 for Mobile & Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app) guide
- Contact Google Cloud Support if needed
