---
module: Canteen UI
date: 2026-06-01
problem_type: ui_bug
component: onboarding_settings
symptoms:
  - "Users could finish onboarding without choosing an exact mensa"
  - "The canteen feature stayed hardcoded to Karlsruhe even when supporting other mensas"
  - "Canteen setup UI did not match the schedule onboarding/setup design"
root_cause: canteen_selection_was_not_modeled_as_required_app_configuration_and_the_data_source_was_hardcoded_to_karlsruhe
resolution_type: code_fix
severity: medium
tags: [canteen, mensa, onboarding, settings, karlsruhe, openmensa, flutter]
---

# Troubleshooting: Required exact mensa selection

## Problem
The app could not support exact mensa selection end to end. Onboarding had no required mensa step, Settings could not reconfigure the canteen source, and the canteen backend was still hardcoded to Karlsruhe.

## Root Cause
The canteen stack only had one implicit source: the Karlsruhe scraper path. There was no persisted selected-location concept, so onboarding and Settings could not drive the runtime provider or widget/background cache behavior.

## Solution
- Added a persisted selected canteen location via `PreferencesProvider` and `CanteenLocationService`.
- Added a required onboarding mensa step that intentionally matches the schedule setup page structure.
- Added a Settings dialog to reselect the exact mensa later.
- Kept Karlsruhe on the existing scraper/model path exactly as before.
- Added an OpenMensa-backed source for the newly supported non-Karlsruhe locations.
- Kept the SQLite/widget cache model minimal by treating the selected mensa as the single active canteen cache and clearing cached meals when the selection changes.

## Test Coverage
- `required canteen step cannot be skipped when invalid`
- `refreshWeek uses OpenMensa for non-Karlsruhe locations`
- existing canteen page bounds, visible-days, and startup loading policy suites updated for the new location service path

## Commands run
```bash
flutter test test/canteen/business/canteen_provider_refresh_policy_test.dart test/canteen/ui/viewmodels/canteen_visible_days_test.dart test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart test/canteen/ui/canteen_page_bounds_test.dart test/ui/onboarding/onboarding_required_canteen_step_test.dart
flutter analyze lib/canteen lib/ui/onboarding lib/ui/settings lib/common/appstart/service_injector.dart test/canteen test/ui/onboarding/onboarding_required_canteen_step_test.dart
```
