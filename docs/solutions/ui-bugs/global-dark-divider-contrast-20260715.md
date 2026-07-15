---
title: Reduce divider contrast across dark-mode pages
date: 2026-07-15
category: ui-bugs
---

# Summary

Dark-mode separators inherited Flutter's default divider color because the app
theme did not define a divider token. This made the Dates header separator and
the Dualis exam table rules much brighter than the surrounding surfaces.

# Fix

- Define the app-wide divider color in `ColorPalettes.buildTheme` for light and
  dark themes.
- Apply the same color through both `ThemeData.dividerColor` and
  `DividerThemeData.color`, covering `Divider`, `Divider.createBorderSide`, and
  consumers that read `Theme.of(context).dividerColor`.
- Keep existing divider spacing and thickness unchanged.

# Related agenda fixes

- Account for the exam-week inset when deciding whether a category icon fits.
- Compare UTC calendar-day values when detecting seven-day event gaps so DST
  transitions do not shorten the result.
- Use `Object.hash` for complete `ImportantEvent` identity hashing.
- Extend theme interpolation and compact-width regression coverage.

# Validation

- Focused Dates/theme/model widget tests: 28 passed.
- Broader date-management, Dualis lazy-rendering, and shared-color tests: 68
  passed with `TZ=Europe/Berlin`.
- `flutter analyze`: no issues.
- Galaxy S21+ (`RFCR31468LJ`): verified the Dates header and Dualis Exams table
  in dark mode at 120 Hz with Extra dim disabled. No Flutter exceptions or
  overflow messages were present in the scoped device log.
