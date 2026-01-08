# Build Information

This APK was compiled for arm64/armv8 architecture.

## Placeholder Files Created

The following placeholder files were created to enable the build:

### 1. Firebase Configuration (google-services.json)
**Path:** `android/app/google-services.json`

This is a placeholder Firebase configuration file. For production use, you need to:
1. Create a Firebase project at https://console.firebase.google.com
2. Add an Android app with package name `de.bennik2000.dhbwstudentapp`
3. Download the real `google-services.json` and replace this placeholder

### 2. Android Signing
The APK is signed with the **debug key** (as configured in `android/app/build.gradle` line 66).

For production release signing:
1. Generate a proper release keystore using:
   ```
   keytool -genkey -v -keystore release-keystore.jks -alias release -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Create `android/key.properties` with:
   ```
   storePassword=your_password
   keyPassword=your_password
   keyAlias=release
   storeFile=../release-keystore.jks
   ```
3. Update `android/app/build.gradle` to use `signingConfigs.release` instead of `signingConfigs.debug`

## Dependency Version Changes

The following dependencies were updated to resolve compatibility issues:

| Dependency | Original Version | Updated Version | Reason |
|------------|-----------------|-----------------|--------|
| firebase_core | ^2.16.0 | ^2.4.0 | Gradle compatibility |
| firebase_analytics | ^10.5.0 | ^10.1.0 | Gradle compatibility |
| firebase_crashlytics | ^3.3.6 | ^3.0.9 | Gradle compatibility |
| device_calendar | ^4.2.0 | ^4.3.1 | Kotlin when-expression fix |
| timezone | ^0.8.0 | ^0.9.0 | device_calendar requirement |
| flutter_local_notifications | ^9.4.1 | ^13.0.0 | timezone ^0.9.0 compatibility |
| flutter_inapp_purchase | ^5.6.1 | ^5.4.2 | meta package compatibility |
| workmanager | ^0.4.1 | ^0.5.0 | Kotlin 1.8.0 compatibility |

## Code Changes

### notification_api.dart
Updated to use the new flutter_local_notifications v13 API:
- `IOSInitializationSettings` → `DarwinInitializationSettings`
- `IOSNotificationDetails` → `DarwinNotificationDetails`
- `onSelectNotification` → `onDidReceiveNotificationResponse`

### android/app/build.gradle
- Updated `compileSdkVersion` from 33 to 34 (required by device_calendar)

## Build Environment

- Flutter: 3.3.10 (as specified in Publish.md)
- Dart SDK: 2.18.6
- Target Platform: android-arm64

## Build Command

```bash
flutter build apk --release --target-platform android-arm64
```

## APK Output

The compiled APK is located at: `dhbw-student-app-arm64.apk`
