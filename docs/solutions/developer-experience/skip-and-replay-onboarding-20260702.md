---
module: Developer Experience
date: 2026-07-02
problem_type: developer_experience
component: development_workflow
symptoms:
  - "Manual onboarding required on every fresh debug install"
  - "No way to re-trigger onboarding from inside a debug build"
root_cause: missing_tooling
resolution_type: feature
severity: low
tags: [developer-options, onboarding, dart-define, debug-mode, testing]
---

# Skip/Replay Onboarding for Debug Builds

## Problem
Testing required walking through the full onboarding on every fresh install, and once completed there was no in-app way to re-trigger the onboarding flow to verify changes to it.

## Solution

### Feature 1: Skip onboarding + seed settings via `flutter run` (`--dart-define`)

Added `DebugStartupOverrides` (`lib/common/appstart/debug_startup_overrides.dart`) which reads compile-time defines and writes them into the persisted preferences during startup, **before** `RootViewModel.loadFromPreferences()` runs (so onboarding is already marked complete when the root view model decides the initial route).

Supported defines (debug builds only):

| Define | Example | Effect |
| --- | --- | --- |
| `SKIP_ONBOARDING` | `true` | Marks first start as completed. |
| `SCHEDULE_SOURCE` | `rapla` | Sets source type (`rapla`/`dualis`/`ical`/`mannheim`/`none`). |
| `RAPLA_URL` | `https://rapla...` | Persists Rapla URL; infers source `rapla` unless `SCHEDULE_SOURCE` is set. |
| `ICAL_URL` | `https://...ics` | Persists iCal URL; infers source `ical` (or `mannheim` when `MANNHEIM_ID` is also set). |
| `MANNHEIM_ID` | `course-id` | Persists Mannheim schedule id. Alone this does **not** select a source (Mannheim is built on the iCal source, so pair with `ICAL_URL` to select `mannheim`). |
| `CANTEEN_LOCATION_ID` | `karlsruhe_erzbergerstrasse` | Persists canteen location (must be a supported id). |

Example:

```sh
flutter run -d <device> \
  --dart-define=SKIP_ONBOARDING=true \
  --dart-define=SCHEDULE_SOURCE=rapla \
  --dart-define=RAPLA_URL=https://rapla.dhbw.de/... \
  --dart-define=CANTEEN_LOCATION_ID=karlsruhe_erzbergerstrasse
```

The whole path is guarded by `kDebugMode` so it is a no-op in release builds.

### Feature 2: Replay onboarding from Developer Options

Added a "Replay onboarding" tile under **Settings → Developer options** (debug builds only). Tapping it persists `IsFirstStart = true` and navigates to the onboarding route via `pushNamedAndRemoveUntil`, so finishing the flow lands cleanly back on `main`.

## Why This Works
- `--dart-define` values are compile-time constants (`String.fromEnvironment`/`bool.fromEnvironment`), so they are free at runtime when unset and never ship to release.
- The override runs after service injection (so `PreferencesProvider` exists) but before preferences are read by the view model.
- The replay button reuses the existing onboarding route/finish handler, so no duplicated navigation logic.

## Tests
- `test/common/appstart/debug_startup_overrides_test.dart`
- `test/ui/settings/settings_developer_replay_onboarding_test.dart`

## Related Docs
- `docs/solutions/developer-experience/developer-options-and-overlay-20260207.md`
