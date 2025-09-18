# Firebase Setup Instructions

This document explains how to set up Firebase for the Match 3 Multiplayer game.

## Prerequisites

1. A Google account
2. Flutter development environment set up
3. Firebase CLI installed (optional but recommended)

## Firebase Console Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `match3-multiplayer` (or your preferred name)
4. Follow the setup wizard

### 2. Enable Authentication

1. In your Firebase project, go to **Authentication**
2. Click **Get started**
3. Go to **Sign-in method** tab
4. Enable **Anonymous** authentication
5. Click **Save**

### 3. Set up Realtime Database

1. Go to **Realtime Database**
2. Click **Create Database**
3. Choose **Start in test mode** (for development)
4. Select your preferred location
5. Click **Done**

### 4. Configure Database Rules

#### Option A: Use the provided rules file (Recommended)

1. Run the Firebase CLI command to deploy the rules:
```bash
firebase deploy --only database
```

This will deploy the rules from `database.rules.json` which includes proper indexing and security.

#### Option B: Manual setup in Firebase Console

In the **Rules** tab of Realtime Database, use these rules:

```json
{
  "rules": {
    "rooms": {
      "$roomId": {
        ".read": "auth != null",
        ".write": "auth != null",
        ".indexOn": ["createdAt", "hostId", "state"],
        "players": {
          "$playerId": {
            ".write": "auth != null && auth.uid == $playerId"
          }
        },
        "gameState": {
          ".read": "auth != null",
          ".write": "auth != null",
          "updates": {
            ".indexOn": ["timestamp", "playerId"]
          }
        }
      }
    },
    "quickMatch": {
      ".read": "auth != null",
      ".write": "auth != null",
      ".indexOn": "createdAt"
    }
  }
}
```

**⚠️ Important:** These rules include proper authentication checks and indexing for optimal performance.

#### For Development Testing (Temporary)

If you need open rules for initial testing, use these **TEMPORARILY**:

```json
{
  "rules": {
    "rooms": {
      "$roomId": {
        ".read": true,
        ".write": true,
        ".indexOn": ["createdAt", "hostId", "state"]
      }
    },
    "quickMatch": {
      ".read": true,
      ".write": true,
      ".indexOn": "createdAt"
    }
  }
}
```

## App Configuration

### 1. Update Firebase Options

Edit `lib/firebase_options.dart` and replace the placeholder values with your actual Firebase configuration:

1. In Firebase Console, go to **Project settings** (gear icon)
2. In **Your apps** section, add your platform (Web, Android, iOS, etc.)
3. Copy the configuration values
4. Replace the values in `firebase_options.dart`

### 2. Platform-Specific Setup

#### Android
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/` directory

#### iOS
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add it to your iOS project in Xcode

#### Web
1. Copy the Firebase configuration from the Firebase Console
2. Update the web configuration in `firebase_options.dart`

## Development vs Production

### Development Settings
- Anonymous authentication enabled
- Open database rules for testing
- Test mode for Realtime Database

### Production Settings (TODO)
- Implement proper authentication
- Secure database rules with user-based access
- Enable security rules for data validation
- Consider implementing Cloud Functions for server-side validation

## Testing the Setup

1. Run the app: `flutter run`
2. Navigate to "Online Multiplayer"
3. Try creating a room - if no errors appear, Firebase is working
4. Check Firebase Console to see if data appears in Realtime Database

## Common Issues

### Authentication Errors
- Ensure Anonymous authentication is enabled in Firebase Console
- Check that your app's package name matches Firebase configuration

### Database Permission Errors
- Verify database rules allow read/write access
- Ensure database URL is correct in `firebase_options.dart`

### Platform-Specific Issues
- **Android**: Ensure `google-services.json` is in the correct location
- **iOS**: Verify `GoogleService-Info.plist` is added to the project
- **Web**: Check browser console for CORS or configuration errors

## Next Steps

Once basic functionality is working:

1. Implement proper user authentication (optional)
2. Add server-side validation using Cloud Functions
3. Implement proper security rules
4. Add error handling and offline support
5. Optimize for production deployment

## Support

For Firebase-specific issues, refer to:
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)