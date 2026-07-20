---
title: Align the paused-reminder notice with the schedule banner
date: 2026-07-18
type: ui-fix
---

# Problem

The paused-reminder notice used a custom horizontal warning layout. Its German
title, explanation, and action competed for width and made the notice unusually
tall and visually inconsistent with the existing missing-schedule-source
notice. The recurring-reminder explanation was also unnecessarily long in
German.

# Solution

- Reused `BannerWidget` for the paused-reminder state.
- Added an optional semibold banner heading while preserving the existing
  banner structure and styling.
- Shortened the German permission and recurring-name-matching copy without
  changing their meaning.
- Added German widget coverage for both notices.

# Verification

- Focused reminder and schedule-page widget tests.
- `flutter analyze`.
- Galaxy S21+ profile-mode cold-start comparison.
