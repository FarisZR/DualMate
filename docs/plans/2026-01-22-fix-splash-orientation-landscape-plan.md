---
title: Fix splash removal, orientation lock, landscape support
type: fix
date: 2026-01-22
---

# Fix splash removal, orientation lock, landscape support

## Overview
Remove the custom splash screen, fix the portrait lock that happens after launch, and make landscape usable on phones and tablets. Improve perceived launch speed by reducing blocking work before the first frame and ensuring a defined initial UI instead of a blank screen.

## Problem Statement / Motivation
- App forces portrait after the splash screen until it is resumed from memory, which breaks landscape use on tablets and phones.
- A custom splash screen adds startup overhead and hides slow initialization, but its removal exposes launch jank and blank frames.
- Landscape/tablet layouts are inconsistent because orientation and device checks are mixed across UI and initialization.

## Proposed Solution
- Remove the native splash setup and related assets/configuration.
- Allow all orientations globally on Android and stop applying a phone-only portrait lock.
- Audit and update landscape/tablet layout decisions to avoid forced portrait assumptions.
- Improve launch speed by moving non-critical initialization after `runApp` and showing a lightweight loading shell while async work completes.
- Document the new behavior and troubleshooting steps in a support doc under `docs/`.

## Technical Considerations
- Orientation is currently enforced in `PlatformUtil.initializePortraitLandscapeMode()` and called in `lib/main.dart` before `runApp`.
- Tablet/landscape layout selection is handled in `lib/ui/main_page.dart` and specific pages like `lib/dualis/ui/exam_results_page/exam_results_page.dart`.
- Splash is configured via `flutter_native_splash` and Android launch theme (`android/app/src/main/res/values/styles.xml` + `android/app/src/main/res/drawable/launch_background.xml`).
- Android 12+ will still show a system splash with app icon; removing custom splash should not be confused with disabling the system one.

## Acceptance Criteria
- [x] No custom splash screen is displayed on launch; any Android system splash uses the default icon only.
- [x] On cold start, the first rendered screen respects the device's current orientation (portrait or landscape).
- [x] Rotating during launch results in the correct orientation without needing a background/resume cycle.
- [x] All top-level screens are usable in landscape on phones and tablets (no overflow errors, key actions visible).
- [x] Launch time to first meaningful UI improves compared to the current baseline (define target after measurement).
- [x] Documentation exists under `docs/` explaining launch behavior and orientation support.

## Success Metrics
- TTFF and TTFMP are measured on a mid-range Android device; target >= 20% improvement after removal of blocking init work.
- Zero orientation-related layout exceptions in landscape for core screens (schedule, dualis, date management, settings, onboarding).

## Dependencies & Risks
- Removing splash reveals initialization delays; if init remains synchronous, launch may appear slower.
- Some UI widgets may still assume portrait and could overflow in landscape.
- Android system splash behavior may be mistaken as a regression if not communicated.

## Implementation Outline
1. Splash removal
   - Remove `flutter_native_splash` usage and assets (`flutter_native_splash.yaml`, `assets/splash.png`).
   - Update Android launch theme to remove `@drawable/launch_background` and unused drawable assets.
2. Orientation policy fix
   - Update `PlatformUtil.initializePortraitLandscapeMode()` to allow all orientations on phones and tablets.
   - Ensure no other orientation locks exist in Android manifest or runtime hooks.
3. Landscape/tablet layout audit
   - Review usage of `PlatformUtil.isPhone()`/`isTablet()` and `isPortrait()` to confirm layouts are usable in landscape.
   - Adjust layouts in key screens if assumptions break in landscape (e.g., `MainPage`, `ExamResultsPage`).
4. Launch speed improvement
   - Move non-critical initialization from `main()` to post-`runApp` async flows.
   - Add a lightweight loading shell in the root page while async initialization completes.
5. Documentation
   - Add `docs/support/launch-and-orientation.md` describing behavior, device expectations, and troubleshooting tips.
   - Update `README.md` with a short note about landscape support and launch behavior.

## References & Research
- Orientation setup: `lib/common/util/platform_util.dart:25`
- App startup order: `lib/main.dart:16`
- Layout branching for phone/tablet: `lib/ui/main_page.dart:50`
- Tablet-specific width adjustments: `lib/dualis/ui/exam_results_page/exam_results_page.dart:174`
- Android launch theme: `android/app/src/main/res/values/styles.xml:3`
- Android launch drawable: `android/app/src/main/res/drawable/launch_background.xml:3`
- Splash config: `flutter_native_splash.yaml:1`

## Testing Plan
- `flutter test`
- Manual device QA (Android):
  - Cold start in landscape and portrait
  - Rotate during launch
  - Resume from recents
  - Tablet landscape with navigation drawer + content
  - Verify no overflow errors and key actions visible

## Documentation Plan
- Add `docs/support/launch-and-orientation.md` with:
  - Expected orientation behavior
  - Android 12+ system splash note
  - Launch troubleshooting steps
  - Known limitations (if any)

## AI-Era Considerations
- Document measurement steps and scripts used for TTFF/TTFMP.
- Flag any AI-generated layout adjustments for manual UI review on real devices.
