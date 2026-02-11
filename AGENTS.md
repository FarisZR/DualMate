# AGENTS.md - Engineering Guide for DualMate

This file is an onboarding and implementation guide for engineers and AI/code agents working in this repository.

## Project Overview

- Project: `DualMate` (Flutter/Dart app for DHBW students)
- Language: Dart
- Framework: Flutter
- Dart SDK: `>=3.0.0 <4.0.0`
- App semver/build: `2.0.0-beta+39`
- Displayed app version: `2.0-beta` (+ build date + commit hash in debug) in `lib/common/application_constants.dart`
- Target platform: Android
- iOS: currently unmaintained, ignore iOS for fixes/features unless explicitly requested

## Build, Run, Test

```bash
flutter pub get
flutter run -d <DEVICE_ID>
flutter test
flutter build apk
flutter build appbundle
```

For performance profiling:

```bash
flutter run --profile -d <DEVICE_ID>
```

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── common/                        # Shared appstart, data, logging, i18n, util, common UI
├── schedule/                      # Schedule feature (sources, cache, weekly/daily UI, background updates)
├── canteen/                       # Canteen scraping/cache/UI/background
├── dualis/                        # Dualis grades/authentication feature
├── date_management/               # Dates/Rapla important events and calendar export
├── information/                   # Useful links/info screens
├── native/                        # Flutter <-> native widget bridge code
└── ui/                            # Root app UI, navigation, onboarding, settings
test/                              # Mirrors lib/ structure with parser/viewmodel/widget tests
docs/                              # Architecture notes, plans, and fix writeups
android/                           # Android native implementation and widgets
ios/                               # Unmaintained (ignore unless explicitly asked)
```

## Code Style Guidelines

### Naming

- Files: `snake_case.dart`
- Classes/Enums: `PascalCase`
- Methods/variables: `camelCase`
- Private members: prefix with `_`
- Constants: follow existing project style (`ApplicationVersion`, etc.)

### Imports

Keep imports grouped consistently:
1. Dart SDK
2. Own package (`package:dualmate/...`)
3. Third-party packages

### Documentation

- Use `///` doc comments for non-trivial public classes/methods.
- Document new fixes/features in `docs/solutions/...` and plans in `docs/plans/...`.
- Keep markdown headings valid (`# Heading`, `## Heading`).

## Architecture Patterns

### MVVM + Property Change Notifier

- ViewModels extend `BaseViewModel` (`lib/common/ui/viewmodels/base_view_model.dart`).
- Prefer `notifyIfMounted("propertyName")` for async-safe updates.
- Avoid heavy constructor work; use guarded `initialize()` methods.
- Remove callbacks/timers/listeners in `dispose()`.

### Dependency Injection (Kiwi)

- Register core services in `lib/common/appstart/service_injector.dart`.
- Resolve via `KiwiContainer().resolve<T>()`.
- Prefer constructor injection for new code instead of resolving deep inside methods.

### Feature module layout

Common layout used across features:

```
feature/
├── model/      # Domain/data models
├── data/       # Repository/database entities
├── service/    # Scrapers/parsers/API integrations
├── business/   # Providers/business orchestration
└── ui/         # ViewModels and widgets/pages
```

## Localization

- Supported locales: English (`en`) and German (`de`)
- Localization entry: `lib/common/i18n/localizations.dart`
- String files:
  - `lib/common/i18n/localization_strings_en.dart`
  - `lib/common/i18n/localization_strings_de.dart`
- Interpolation format uses `%0`, `%1`, etc.

## High-Value Architecture Map

### App startup path

1. `lib/main.dart`
2. `lib/ui/root_page.dart`
3. `lib/common/appstart/app_initializer.dart`
4. `lib/ui/main_page.dart`

Key behavior:
- First frame is deferred, then allowed as early as possible.
- Base init (`initializeAppBase`) runs before first usable UI.
- Heavy foreground work is deferred post-frame (`initializeAppForegroundHeavy`) to reduce launch jank.
- Startup/perf markers are logged through `PerformanceTelemetry`.

### Dependency injection

- DI container: Kiwi (`lib/common/appstart/service_injector.dart`)
- Most app singletons are registered there: providers, repositories, schedule source provider, Dualis services, widget helper, etc.
- Prefer constructor injection in new code.

### Navigation and routes

- Root routes (`generateRoute`): `onboarding`, `main`, `settings`
- Drawer routes (`generateDrawerRoute`) are backed by `navigationEntries` in `lib/ui/navigation/router.dart`:
  - `schedule`
  - `canteen`
  - `dualis`
  - `date_management`
  - `usefulInformation`
- `MainPage` hosts a nested navigator (`NavigatorKey.mainKey`) with phone/tablet-specific scaffold layouts.

## Feature Modules and Core Paths

### Schedule (`lib/schedule`)

- Main UI: `lib/schedule/ui/schedule_page.dart`
- Weekly VM: `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart`
- Data service/cache: `lib/schedule/business/schedule_provider.dart`
- Source switching: `lib/schedule/business/schedule_source_provider.dart`

Important runtime behavior:
- Cache-first rendering, then stale-window background refresh.
- Range-aware freshness and request gating.
- Background widget refresh updates data without mutating visible week:
  - `updateSchedule(..., applyToVisibleState: false)`
- Filters must force refresh and invalidate cached ranges where needed.

### Date Management (`lib/date_management`)

- View model: `lib/date_management/ui/viewmodels/date_management_view_model.dart`
- Default source is Rapla important events (DHmine optional via settings toggle).
- Rapla events are derived from shared schedule cache (not a separate legacy cache).
- Pagination is windowed (3-month chunks), throttled, and bounded.

### Canteen (`lib/canteen`)

- View model: `lib/canteen/ui/viewmodels/canteen_view_model.dart`
- Page: `lib/canteen/ui/canteen_page.dart`
- Provider/repository: `lib/canteen/business/canteen_provider.dart`, `lib/canteen/data/canteen_meal_repository.dart`
- Scraping/parsing offloads heavy parsing to isolate path in service layer.
- UI is day-based with visible-content-day bounds (recent fixes prevent invalid swipe pages/overscroll edge issues).

### Dualis (`lib/dualis`)

- Navigation entry and page under `lib/dualis/ui`
- Service stack includes cache decorator + scraper/authentication in `lib/dualis/service`

### Widgets and native bridge (`lib/native`, `android/.../widget`)

- Widget refresh bridging: `lib/native/widget/widget_update_callback.dart`
- Android method channel helper: `lib/native/widget/android_widget_helper.dart`
- Widget payloads are routed into app via `RootPage` method channel and `WidgetNavigationPayloadStore`.

## Background Jobs and Scheduling

- Background scheduler setup: `lib/common/appstart/background_initialize.dart`
- Tasks:
  - `BackgroundScheduleUpdate` (~every 4h)
  - `BackgroundCanteenUpdate` (~every 8h)
  - `NextDayInformationNotification`
- Android uses real scheduler service; non-Android gets no-op scheduler.

## ViewModel and Lifecycle Rules

- Base class: `lib/common/ui/viewmodels/base_view_model.dart`
- Always use `notifyIfMounted(property)` for async/state updates.
- Avoid heavy work in constructors; use guarded `initialize()` methods.
- Remove callbacks/timers/listeners in `dispose()`.
- For async refreshes, guard disposed state and stale-range application.

## Testing Guidance

- Test tree mirrors feature structure in `test/`.
- Run targeted tests for touched areas, then broader suites.
- High-signal suites recently expanded:
  - `test/schedule/ui/viewmodels/*`
  - `test/schedule/ui/weeklyschedule/*`
  - `test/canteen/ui/*`
  - parser/fixture tests under `test/.../html_resources`

Use real Android device runs for final verification of:
- lifecycle/resume behavior
- widget tap navigation/payload handling
- background refresh and performance

## Documentation Workflow

- Record fixes in `docs/solutions/<category>/...md` with frontmatter.
- Keep implementation plans in `docs/plans/`.
- Canonical behavior docs to consult before touching core flows:
  - `docs/modernizing.md`
  - `docs/rapla-cache-refresh-behavior.md`
  - `docs/rapla-schedule-cache-merge.md`
  - `docs/canteen-feature.md`
  - `docs/multi-day-widgets.md`
  - `docs/support/launch-and-orientation.md`

## Adding new features

- Test driven development, write automated tests first with full coverage.
- You should continue till the feature is implemented correctly with no errors.
- Test your final changes using the debugger and the connected android device by reading the logs and checking for issues.
- target Material you (Material 3) design language (https://m3.material.io/develop/flutter, https://m3.material.io/foundations/content-design/overview)

## Practical Notes

- `README.md` is marked TODO and is not the source of truth for current architecture.
- `android/build/...` contains generated artifacts; do not treat them as source docs.
- There is no strict custom lint config (`analysis_options.yaml` absent).
- Keep new UI work aligned with Material 3 patterns already used in current screens.
