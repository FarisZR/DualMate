---
title: Android widget previews updated for schedule and canteen
date: 2026-03-08
---

# Summary

The widget picker previews for the schedule and canteen widgets no longer
matched the current multi-day widget UI. The canteen widget also reused the
schedule preview asset, the canteen date could overflow in the picker preview,
and both widgets still appeared under the generic app name.

# Cause

- `android/app/src/main/res/xml/canteen_today_widget_info.xml` pointed to the
  schedule preview image.
- Both widgets still depended on older static preview assets from before the
  multi-day widget redesign.
- Android 12+ launchers can show richer scalable previews through
  `android:previewLayout`, but the widgets did not provide one.

# Fix

- Added dedicated scalable preview layouts:
  - `android/app/src/main/res/layout/widget_schedule_now_preview.xml`
  - `android/app/src/main/res/layout/widget_canteen_today_preview.xml`
- Updated widget metadata to use `android:previewLayout` on supported launchers.
- Refreshed the schedule fallback preview PNG and added a dedicated canteen
  fallback preview PNG for older widget hosts.
- Pointed the canteen widget info file at its own preview asset.
- Tightened both previews so content reads larger in the picker and widened the
  canteen preview date column to prevent clipped dates.
- Gave each widget receiver its own picker label (`Schedule` / `Canteen`) so
  launchers no longer show both widgets as `DualMate`.

# Validation

- `flutter build apk --debug`
- `flutter install --debug -d RFCR31468LJ`

# Device check

- Installed the updated debug build on the connected S21 (`RFCR31468LJ`) so the
  new widget resources are packaged for on-device verification.
