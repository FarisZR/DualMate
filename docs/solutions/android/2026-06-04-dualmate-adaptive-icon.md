---
title: DualMate Android adaptive icon replacement
date: 2026-06-04
category: android
---

## Problem

The Android launcher icon and in-app branding asset still used the old bitmap
icon. The project also did not define an Android adaptive icon, so launchers
could not mask the icon consistently or use a themed monochrome layer.

## Solution

- Replaced the Flutter branding asset at `assets/app_icon.png` with the refined DualMate icon.
- Added adaptive launcher icon resources in `mipmap-anydpi-v26` with foreground,
  background, and monochrome layers.
- Regenerated legacy density fallback PNGs in `mipmap-*dpi`.
- Added `android:roundIcon` so round launcher contexts use the new adaptive icon.
- Updated the splash background to reference the vector foreground directly
  instead of loading `@mipmap/ic_launcher` through a bitmap node.
