# 🔥 Firebase Setup Guide for Grazia Stones

## Prerequisites
- Firebase account ([https://firebase.google.com](https://firebase.google.com))
- Flutter CLI installed
- FlutterFire CLI installed

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project"
3. Project name: `grazia-stones` (or `grazia-stones-dev` for development)
4. Enable Google Analytics (recommended)
5. Create project

## Step 2: Install FlutterFire CLI

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Verify installation
flutterfire --version
```

## Step 3: Configure Firebase for Flutter

```bash
# Run in project root directory
cd /Users/raghavshah/01_ACTIVE_PROJECTS/grazia-stones

# Login to Firebase (if not already logged in)
firebase login

# Configure Firebase for this Flutter project
flutterfire configure
```

This will:
- List your Firebase projects
- Let you select `grazia-stones`
- Ask which platforms to configure (select Android, iOS, Web)
- Generate `firebase_options.dart` automatically
- Generate platform-specific config files

## Step 4: Enable Firebase Services

### 4.1 Authentication
1. Go to Firebase Console → Authentication
2. Click "Get Started"
3. Enable "Phone" sign-in method
4. Configure phone number authentication settings
5. Add test phone numbers (optional, for testing)

### 4.2 Firestore Database
1. Go to Firebase Console → Firestore Database
2. Click "Create database"
3. Start in **production mode** (we'll add security rules later)
4. Choose location: `asia-south1` (Mumbai) for Indian users
5. Click "Enable"

### 4.3 Firebase Storage
1. Go to Firebase Console → Storage
2. Click "Get started"
3. Start in **production mode**
4. Use default location
5. Click "Done"

### 4.4 Firebase Analytics (Optional but Recommended)
- Already enabled if you selected it during project creation
- No additional setup needed

## Step 5: Configure Android

### 5.1 Add google-services.json
```bash
# Download from Firebase Console → Project Settings → Your apps → Android app
# Place it at:
android/app/google-services.json
```

### 5.2 Update android/build.gradle
```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

### 5.3 Update android/app/build.gradle
```gradle
// Add at the bottom of the file
apply plugin: 'com.google.gms.google-services'
```

### 5.4 Update AndroidManifest.xml
Already done - camera and internet permissions are present.

## Step 6: Configure iOS

### 6.1 Add GoogleService-Info.plist
```bash
# Download from Firebase Console → Project Settings → Your apps → iOS app
# Place it at:
ios/Runner/GoogleService-Info.plist
```

### 6.2 Update iOS Podfile
```ruby
# ios/Podfile - Already configured, just run:
cd ios
pod install
cd ..
```

### 6.3 Update Info.plist
Add camera and location permissions (if not already present):

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access for AR stone visualization</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need location access to find nearby dealers</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to save AR screenshots</string>
```

## Step 7: Configure Web

### 7.1 Add Firebase config to web/index.html
```html
<!-- Already configured by flutterfire configure -->
<!-- Verify in web/index.html -->
```

## Step 8: Update Firebase Security Rules

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Stones collection (public read, admin write)
    match /stones/{stoneId} {
      allow read: if true;
      allow write: if false; // Only backend can write
    }
    
    // Collections (public read)
    match /collections/{collectionId} {
      allow read: if true;
      allow write: if false;
    }
    
    // Wishlist
    match /wishlists/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Orders (user can only read their own)
    match /orders/{orderId} {
      allow read: if request.auth != null && 
                    request.auth.uid == resource.data.userId;
      allow write: if false; // Only backend can create orders
    }
  }
}
```

### Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // User uploads (profile pictures)
    match /users/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId
                    && request.resource.size < 5 * 1024 * 1024; // 5MB max
    }
    
    // Stone images (read-only for users)
    match /stones/{allPaths=**} {
      allow read: if true;
      allow write: if false; // Only admin can upload
    }
    
    // AI visualization results (user-specific)
    match /visualizations/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 9: Test Firebase Connection

```bash
# Run the app
flutter run

# Check console for Firebase initialization messages:
# ✅ Firebase service initialized
# ✅ Storage service initialized
# ✅ API service initialized
# ✅ ML Kit service initialized
# ✅ Payment service initialized
```

## Step 10: Environment Variables

Create `.env` file in project root (copy from `.env.example`):

```bash
# Firebase
FIREBASE_PROJECT_ID=grazia-stones
FIREBASE_STORAGE_BUCKET=grazia-stones.appspot.com

# Get these from Firebase Console → Project Settings → General
FIREBASE_ANDROID_API_KEY=your_actual_android_api_key
FIREBASE_IOS_API_KEY=your_actual_ios_api_key
FIREBASE_WEB_API_KEY=your_actual_web_api_key
```

## Troubleshooting

### Issue: "Default FirebaseApp is not initialized"
**Solution:** Make sure `flutterfire configure` was run and `firebase_options.dart` exists

### Issue: "Phone authentication not working"
**Solution:** 
1. Check if Phone auth is enabled in Firebase Console
2. Verify SHA-1 fingerprint is added for Android
3. For iOS, check if APNs certificate is configured

### Issue: "Storage upload fails"
**Solution:** Check Firebase Storage rules and file size limits

### Common Commands

```bash
# Reconfigure Firebase
flutterfire configure

# Get SHA-1 fingerprint (Android)
cd android
./gradlew signingReport

# Clean and rebuild
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## Next Steps

After Firebase is configured:
1. Test phone authentication flow
2. Test Firestore read/write
3. Test Storage upload
4. Configure Firebase Cloud Messaging (for push notifications)
5. Set up Firebase Analytics events

## Production Checklist

- [ ] Create separate Firebase project for production
- [ ] Configure production Firebase (run `flutterfire configure`)
- [ ] Update security rules for production
- [ ] Enable App Check for security
- [ ] Set up Firebase budget alerts
- [ ] Configure Firebase Extensions (if needed)
- [ ] Test all Firebase features in production environment

---

**Need Help?**
- Firebase Documentation: https://firebase.google.com/docs/flutter/setup
- FlutterFire Documentation: https://firebase.flutter.dev
