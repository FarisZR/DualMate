---
title: Sync loaded canteen tab after Settings location changes
date: 2026-06-11
---

# Summary

Changing the selected canteen from Settings updated Settings state, but an
already-loaded Canteen tab kept its existing `CanteenViewModel` and could show
the old location and cached meals until another reload path ran.

# Changes

- `CanteenLocationService` now broadcasts selected-location changes after
  persisting them.
- `CanteenViewModel` subscribes while initialized and reloads its selected
  location when the shared service changes.
- Test canteen location services emit the same broadcast path as production.

# Validation

- `flutter test test/canteen/business/canteen_location_service_test.dart test/canteen/ui/viewmodels/canteen_visible_days_test.dart`
