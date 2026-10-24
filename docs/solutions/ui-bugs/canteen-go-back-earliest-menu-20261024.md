---
title: Return to the earliest available canteen menu
date: 2026-10-24
type: bugfix
issue: 146
---

The canteen's former “Back to today” button could remain visible after today's
menu disappeared, and tapping it chose the nearest available day instead.

The action is now “Go back” (German: “Zurück”), with a back arrow. It returns to
`visibleContentDays.first`, the earliest available menu in the loaded pager.
The button is hidden and ignores input when there are no menus or the earliest
menu is already selected. It listens to week-state changes as well as selected
date changes so removing menus updates the action even without a swipe. The tap
handler reads the current available days again before navigating.

Regression widget tests cover empty menus, a single available menu with today
absent, both localized labels, changing the earliest available menu, and tapping
the button to navigate back.

Validation uses Flutter 3.47.8 (matching CI) and `TZ=UTC flutter test`. UTC avoids
a separate existing DST bug in weekday normalization on 2026-10-24 in
Europe/Berlin; that bug is recorded in the friction log. `flutter analyze` is
also run. Android visual captures, device logs and the full cold-navigation
performance harness require a connected device; none was available locally.
