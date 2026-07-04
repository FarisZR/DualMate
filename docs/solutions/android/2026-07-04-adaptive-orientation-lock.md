---
title: Adaptive orientation lock for phone-sized displays
type: fix
date: 2026-07-04
---

# Summary

DualMate now locks orientation to portrait only when the real display is
phone-sized. Tablets, foldables, and large-screen/windowed devices leave
orientation unrestricted so Android can use normal portrait and landscape
behavior.

# Implementation

- `PlatformUtil.initializePortraitLandscapeMode()` attaches an
  `AdaptiveOrientationLock` after `runApp`, preserving non-blocking startup.
- The lock reads `FlutterView.display.size / display.devicePixelRatio` and uses
  shortest side `< 600dp` as the phone breakpoint.
- Phone-sized displays call `SystemChrome.setPreferredOrientations()` with
  `portraitUp` and `portraitDown`.
- Tablet and large-screen displays call `SystemChrome.setPreferredOrientations`
  with an empty orientation list, leaving orientation unrestricted.
- The lock observes display metric changes and re-applies the policy when the
  display crosses the breakpoint.

# Validation

- `flutter test test/common/util/adaptive_orientation_lock_test.dart`

Covered cases:

- phone portrait stays portrait-only
- phone landscape is forced back to portrait
- tablet landscape remains unrestricted
- metric changes from phone to large screen remove the portrait restriction
