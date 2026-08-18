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

> Superseded by the 2026-08-19 follow-up below: the `previewLayout` implementation described in this original fix was removed and replaced with real widget captures.

- Added dedicated scalable preview layouts:
  - `android/app/src/main/res/layout/widget_schedule_now_preview.xml`
  - `android/app/src/main/res/layout/widget_canteen_today_preview.xml`
- Updated widget metadata to use `android:previewLayout` on supported launchers.
- Refreshed the schedule fallback preview PNG and added a dedicated canteen
  fallback preview PNG for older widget hosts.
- Pointed the canteen widget info file at its own preview asset.
- Tightened both previews so content reads larger in the picker and widened the
  canteen preview date column to prevent clipped dates.
- Increased the visual scale again so launcher previews read more like the old
  closer-cropped assets while keeping the refreshed multi-day content.
- Reworked the preview composition to scale proportionally and regenerated the
  fallback images with high-resolution downsampling so the picker text stays
  crisp instead of looking aliased.
- Gave each widget receiver its own picker label (`Schedule` / `Canteen`) so
  launchers no longer show both widgets as `DualMate`.

# Validation

- `flutter build apk --debug`
- `flutter install --debug -d RFCR31468LJ`

# Device check

- Installed the updated debug build on the connected S21 (`RFCR31468LJ`) so the
  new widget resources are packaged for on-device verification.

## 2026-08-19 follow-up: Samsung picker drift

Samsung One UI did not reliably render the scalable `previewLayout` versions.
On the Galaxy S21+ the picker could show `Couldn't add widget`, while the
hard-coded layouts also drifted from the actual `RemoteViews` UI (notably emoji
rendering and spacing).

The previews now use screenshots captured from the real 4x2 widgets on the
Galaxy S21+ as the `previewImage` fallback, with the same rounded transparency
as the widget background. The separate preview layouts and preview generator
were removed so there is no second implementation of the widget UI to drift.

Both widget providers also declare a 4x2 target cell size. One UI therefore
shows the preview at the same useful size that was used for the device capture
instead of presenting the widgets as 1x1 by default.

While validating the canteen widget with live DHBW.app data, the native widget
was also updated to recognize `main`/`Hauptgericht` categories in addition to
the legacy Karlsruhe `Wahlessen 1/2` labels. This keeps the real widget preview
representative for all supported canteen sources.

Validation for the follow-up included the targeted native widget unit test, a
debug APK build, and Samsung One UI picker verification on the connected Galaxy
S21+. The picker showed both `Canteen` and `Schedule` as 4x2 static previews and
no longer displayed the preview-layout error.
