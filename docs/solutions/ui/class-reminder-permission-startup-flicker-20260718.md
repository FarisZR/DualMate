---
title: Preventing the class-reminder permission banner from flashing at startup
date: 2026-07-18
category: ui
tags:
  - schedule
  - reminders
  - permissions
  - startup
---

# Preventing the class-reminder permission banner from flashing at startup

The reminder controller previously represented both an unchecked permission
state and a verified denial with `_permissionsGranted == false`. During startup,
persisted reminder rules were loaded and listeners were notified before Android
finished the notification and exact-alarm permission queries. The schedule page
therefore rendered the paused banner briefly even when both permissions were
already granted.

The controller now tracks whether the permission result is known separately
from whether it is granted. `remindersPaused` remains false while the two
platform checks are pending and becomes true only after a verified denial or a
permission-query failure. This preserves the persistent warning for genuinely
missing permissions without exposing provisional startup state to the UI.

The regression test holds both Android permission futures open after reminder
rules load. It verifies that the warning never renders for eventually granted
permissions and that either a notification-permission denial or an exact-alarm
denial renders the warning once verification completes.
