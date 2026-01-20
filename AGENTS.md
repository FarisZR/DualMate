# AGENTS.md - AI Agent Guidelines for DHBW Student App

This document provides guidelines for AI coding agents working on this Flutter/Dart codebase.

## Project Overview

- **Project**: DHBW Student Information App - Mobile app for DHBW Stuttgart students
- **Language**: Dart
- **Framework**: Flutter (cross-platform mobile)
- **Dart SDK**: `>=2.10.0 <3.0.0`
- **App Version**: See `lib/common/application_constants.dart`
- **Status**: Unmaintained (original developer no longer a DHBW student)
- **Goal**: Modernize the app and resolve platform-specific issues with fully correct fixes (e.g., request required permissions instead of only applying workarounds).

## Build Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run the app (debug mode)
flutter build apk            # Build Android APK
flutter build appbundle      # Build Android App Bundle (for Play Store)
flutter clean ios && flutter build ios  # Build iOS
flutter clean                # Clean project
```

## Test Commands

```bash
flutter test                 # Run all tests
flutter test test/common/util/string_utils_test.dart  # Run single test file
flutter test test/dualis/    # Run tests in a directory
flutter test --verbose       # Run with verbose output
flutter test --coverage      # Run with coverage
```

## Project Structure

```
lib/
├── main.dart                # App entry point
├── common/                  # Shared code (appstart, data, i18n, ui, util)
├── schedule/                # Schedule feature (Rapla/Dualis integration)
├── dualis/                  # Dualis grades feature
├── date_management/         # Date/calendar management
└── ui/                      # Main UI (navigation, onboarding, settings)
test/                        # Unit tests (mirrors lib/ structure)
android/                     # Android native code (Kotlin)
ios/                         # iOS native code (Swift)
```

## Code Style Guidelines

### Naming Conventions
- **Files**: `snake_case.dart` (e.g., `schedule_entry.dart`, `base_view_model.dart`)
- **Classes**: `PascalCase` (e.g., `ScheduleEntry`, `DualisService`)
- **Enums**: `PascalCase` with `PascalCase` values (e.g., `ScheduleEntryType.Class`)
- **Constants**: `PascalCase` (e.g., `ApplicationVersion`, `RateInStoreLaunchAfter`)
- **Variables/Methods**: `camelCase` (e.g., `loginState`, `loadStudyGrades()`)
- **Private members**: prefix with `_` (e.g., `_dualisService`, `_loginState`)

### Import Organization
```dart
import 'dart:io';                                           // 1. Dart SDK
import 'package:dhbwstudentapp/common/appstart/app_initializer.dart';  // 2. Own package
import 'package:flutter/material.dart';                     // 3. Third-party
```

### Documentation
Use triple-slash `///` doc comments:
```dart
///
/// This class handles authentication with the Dualis API.
///
class DualisAuthentication {
```

## Architecture Patterns

### MVVM Pattern
- ViewModels extend `BaseViewModel` (uses `PropertyChangeNotifier`)
- Call `notifyListeners("propertyName")` to notify property changes

### Dependency Injection
- Use `KiwiContainer` (see `lib/common/appstart/service_injector.dart`)
- Register: `KiwiContainer().registerInstance(MyService())`
- Resolve: `KiwiContainer().resolve<MyService>()`

### Feature Module Structure
```
feature/
├── model/      # Data models/entities
├── data/       # Repositories, database entities
├── service/    # Business services, API calls, parsing
├── business/   # Business logic providers
└── ui/         # viewmodels/ and widgets/
```

## Error Handling

```dart
// Try-catch with specific exceptions
try {
  var result = await _dualisService.login(username, password);
} on OperationCancelledException catch (_) {
  success = false;
}

// Rethrow with logging
try {
  // operation
} on ScheduleQueryFailedException catch (e, trace) {
  print("Failed to fetch schedule!");
  print(e.innerException.toString());
  print(trace);
  rethrow;
}
```

## Testing Patterns

```dart
import 'package:dhbwstudentapp/common/util/string_utils.dart';
import 'package:test/test.dart';

void main() {
  test('String interpolation', () async {
    var format = "%0 %1!";
    var result = interpolate(format, ["Hello", "world"]);
    expect(result, "Hello world!");
  });
}
```

Parser tests use HTML fixtures:
```dart
var htmlContent = await File(
  Directory.current.absolute.path +
  '/test/schedule/service/rapla/html_resources/rapla_response.html'
).readAsString();
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `property_change_notifier` | ViewModel notifications |
| `kiwi` | Dependency injection |
| `sqflite` | Local SQLite database |
| `shared_preferences` | Key-value storage |
| `flutter_secure_storage` | Secure credential storage |
| `http` | HTTP requests |
| `html` | HTML parsing |
| `workmanager` | Background tasks |

## Localization

- Languages: English (`en`), German (`de`)
- Files: `lib/common/i18n/localization_strings_en.dart`, `localization_strings_de.dart`
- String interpolation: `%0`, `%1`, etc. placeholders

## Version Updates

1. Update `lib/common/application_constants.dart`: `ApplicationVersion`
2. Update `android/app/build.gradle`: `flutterVersionCode` and `flutterVersionName`
3. Update iOS: Runner project version in Xcode

## Important Notes

- No `analysis_options.yaml` - no custom lint rules enforced
- Native code: Android (Kotlin), iOS (Swift) with widget extensions
- Background tasks use `workmanager` package

## Recent Stabilization Changes (Jan 2026)

These changes were made to unblock runtime crashes and improve reliability.

### Schedule Feature
- Providers for `WeeklyScheduleViewModel` and `DailyScheduleViewModel` are now scoped in `SchedulePage` builders. This prevents `ProviderNotFoundException` in `WeeklySchedulePage`.
- `PagerWidget` no longer injects providers. It only switches pages; feature pages now own their provider scope.
- `WeeklyScheduleViewModel` guards access to its date range until initialization is complete.
- Schedule DB updates build the row map only after `entry.id` is set, avoiding null ID update errors.

### Date Management
- `DateManagementViewModel` now initializes `_currentSelectedYear` and `_currentDateDatabase` synchronously to prevent `LateInitializationError` and dropdown value assertions when preferences load asynchronously.

### Dualis Login
- `LoginForm` guards async `setState()` calls with `mounted` checks to avoid lifecycle crashes after disposal.

### Theme
- Theme construction now derives from `ThemeData.light()` / `ThemeData.dark()` with explicit dark surfaces and input decoration styles for hint/label contrast.

## Debugging Notes

- Device runs are stable across schedule/date management screens, but Android device connections can drop during long sessions. Re-run `flutter run -d <deviceId>` if the device disconnects.
- See [docs/modernizing.md](docs/modernizing.md) for a full change rationale and debugging trail.

## Agent Expectations

- Fix issues completely by implementing the true platform requirements (e.g., request required permissions via the correct OS flow instead of relying on fallbacks alone).
- Always use the debugger to test changes on an actual Android phone.
