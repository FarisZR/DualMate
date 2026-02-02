---
title: Dark mode surface tint and light mode status bar icons
date: 2026-02-02
problem_type: ui_bug
module: Theme
component: ThemeData / System UI
severity: medium
symptoms:
  - "Dark mode shows a purple cast on calendar and onboarding blocks"
  - "Light mode shows reddish background on some pages"
  - "Android status bar uses white icons in light mode"
root_cause: Material 3 surface tint defaults and missing SystemUiOverlayStyle
resolution_type: code_fix
tags: [theme, material3, surfaceTint, statusbar, android, dark-mode, light-mode]
---

# Troubleshooting: Surface tint and status bar icon contrast

## Problem
Material 3 applies a `surfaceTintColor` overlay on elevated surfaces. In this app, dark mode surfaces picked up a purple tint and light mode surfaces picked up a red tint from the primary swatch. In parallel, the Android status bar icons stayed white in light mode because the `AppBar` is transparent and no explicit `SystemUiOverlayStyle` was configured.

## Investigation
- Confirmed `ThemeData` uses `ColorScheme.fromSwatch` without an explicit `surfaceTint` override.
- Found that `AppBarTheme` does not set `systemOverlayStyle` while using a transparent background, which can lead to incorrect status bar icon contrast on Android.

## Solution
- Set `surfaceTint: Colors.transparent` in the global `ColorScheme` to disable Material 3 tinting.
- Define `systemOverlayStyle` in `AppBarTheme` to ensure Android status bar icons follow theme brightness.
- Explicitly set neutral `scaffoldBackgroundColor`, `canvasColor`, `cardColor`, and `dialogBackgroundColor` for light and dark themes to avoid swatch-tinted surfaces.
- Keep existing dark background values (`#121212` scaffold, `#1E1E1E` surface) consistent.
- Refresh the app theme when platform brightness changes so `AppTheme.System` reacts without restarting.
- Ensure schedule entry titles use high-contrast text on colored cards (white on red in light mode).

## Code References
- Theme changes: `lib/common/ui/colors.dart`
- System theme refresh: `lib/ui/root_page.dart`, `lib/common/ui/viewmodels/root_view_model.dart`
- Schedule entry contrast: `lib/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart`, `lib/schedule/ui/dailyschedule/widgets/daily_schedule_entry_widget.dart`

## Verification
- Dark mode: calendar block, onboarding tiles, and navigation buttons show neutral dark background with no purple hue.
- Light mode: page backgrounds remain neutral white without red cast.
- Android: status bar icons are dark in light mode and light in dark mode.
- Switch system theme while the app is open: the UI updates without app restart.
- Schedule entry titles remain readable on red cards in light mode.

## Prevention
- Always set `surfaceTint` and `systemOverlayStyle` explicitly when using Material 3 and transparent app bars.
- Prefer a single source of truth in `ColorPalettes.buildTheme` for surface colors and overlays.
