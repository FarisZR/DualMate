# AGENTS.md - AI Agent Guidelines for DualMate

This document provides guidelines for AI coding agents working on this Flutter/Dart codebase.

## Project Overview

- **Project**: DualMate - Mobile app for DHBW (ka) students
- **Language**: Dart
- **Framework**: Flutter (cross-platform mobile)
- **Dart SDK**: `>=2.10.0 <3.0.0`
- **App Version**: See `lib/common/application_constants.dart`
- **Target Platform**: Android, IOS is to be ignored.

## Build Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run the app (debug mode)
flutter build apk            # Build Android APK
flutter build appbundle      # Build Android App Bundle (for Play Store)
```

## Test Commands

```bash
flutter test                 # Run all tests
```
```bash
flutter run -d <DEVICE_ID> #run the app on a real device to see the logs
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
import 'package:dualmate/common/logging/performance_telemetry.dart'; // 2. Own package
import 'package:flutter/material.dart';                     // 3. Third-party
```
Note: Always group own-package imports before third-party imports.

### Documentation
Use triple-slash `///` doc comments for classes and methods.
Markdown headings in documentation must always have a space and proper prefix (e.g., `# Heading`, `## Subheading`).
New features and fixes are to be documented under the `docs` directory.

## Architecture Patterns

### MVVM Pattern
- ViewModels extend `BaseViewModel` (uses `PropertyChangeNotifier`)
- Use `notifyIfMounted("propertyName")` instead of `notifyListeners` to safely notify property changes after async work.
- Avoid heavy initialization in constructors; use an async `initialize()` method instead.
- Ensure all callbacks (e.g., `_onDidChangeScheduleSource`) are removed in `dispose()`.

### Dependency Injection
- Use `KiwiContainer` (see `lib/common/appstart/service_injector.dart`)
- **Preferred**: Inject dependencies via the constructor rather than resolving inside methods.
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

## Important Notes

- No `analysis_options.yaml` - no custom lint rules enforced
- Native code: Android (Kotlin), iOS (Swift) with widget extensions
- Background tasks use `workmanager` package

## Debugging Notes

- Device runs are stable across schedule/date management screens, but Android device connections can drop during long sessions. Re-run `flutter run -d <deviceId>` if the device disconnects.
- See [docs/modernizing.md](docs/modernizing.md) for a full change rationale and debugging trail.
- Fix issues completely by fixing the root cause and by implementing the modern fix (e.g., request required permissions via the correct OS flow instead of relying on fallbacks alone).
- Always use the debugger to test changes on an actual Android phone.


## Adding new features

- Test driven development, write automated tests first with full coverage.
- You should continue till the feature is implemented correctly with no errors.
- Test your final changes using the debugger and the connected android device by reading the logs and checking for issues.
- target Material you (Material 3) design language (https://m3.material.io/develop/flutter, https://m3.material.io/foundations/content-design/overview)
