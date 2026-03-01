---
title: Keep drawer close animation smooth on cold page switches
date: 2026-03-01
---

# Summary

Cold-start navigation from Schedule to heavier sections (Dualis, Dates) could
freeze drawer-close animation on Pixel devices because section switching started
while the drawer close transition was still running.

# Findings

1. Drawer item taps changed `_currentEntryIndex` immediately.
2. First-time section activation (`_loadedSections.add(index)`) builds a new
   section subtree and can allocate view-model/provider trees.
3. On cold startup, doing this work during drawer close transition caused
   visible animation hitching.

# Changes

- `lib/ui/main_page.dart`
  - keep phone drawer taps as pending navigation while drawer is open.
  - apply pending section switch after a short post-close delay
    (`260ms`) so section build work starts after drawer animation.

- `integration_test/drawer_switch_responsiveness_test.dart`
  - added device integration coverage for cold startup drawer switches:
    - open drawer and tap Dualis,
    - assert heavy page is not switched in the immediate post-tap frame,
    - verify switch completes after close,
    - repeat for Dates page.

# Validation

- `flutter analyze lib/ui/main_page.dart integration_test/drawer_switch_responsiveness_test.dart`
- `flutter test integration_test/drawer_switch_responsiveness_test.dart -d 39181FDJG006DP`
