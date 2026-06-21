---
title: Android per-app language opt-in (system App Language menu)
date: 2026-06-21
category: android
---

## Problem

The app did not opt into Android's per-app language preference, so it never
appeared in the system **Settings > App > DualMate > Language** menu on
Android 13+ (API 33+). Users could only change the language by changing the
whole device language; there was no way to set a language for the app that
differs from the OS.

## Solution

- Added `android/app/src/main/res/xml/locales_config.xml` declaring the two
  supported locales (`en`, `de`). English matches the unqualified
  `res/values/` resources and therefore acts as the default.
- Added `android:localeConfig="@xml/locales_config"` to the `<application>`
  element in `AndroidManifest.xml`. This is the single attribute Android 13+
  looks for to surface the app in the system "App language" picker.

## Why no Dart changes were needed

`MaterialApp` in `lib/ui/root_page.dart` does not pass an explicit `locale`,
so Flutter follows `PlatformDispatcher.instance.locale`. When the user picks a
per-app language in system Settings, Android updates that platform locale
process-wide and fires `onLocaleChanged`, which rebuilds `Localizations`. The
custom `LocalizationDelegate.load()` (`lib/common/i18n/localizations.dart`) is
re-invoked with the new locale, so the UI updates at runtime and on cold start.

The Android home-screen widget labels (`res/values*/strings.xml`) are already
locale-qualified, so they follow the per-app choice automatically as well.

The existing `LastUsedLanguageCode` preference (used by the background isolate
for notifications) keeps working because `Platform.localeName` reflects the
per-app locale.

## Verification

- `:app:processDebugManifest --rerun-tasks` succeeds (exit 0); the attribute
  survives both the conditional-manifest generation step and the manifest
  merger, landing in the final merged manifest, and the `@xml/locales_config`
  reference resolves.
- Manual/on-device: on Android 13+, the app appears in the system App Language
  menu; selecting English or German updates the in-app UI and widget labels.

## Notes / future

- This is the system-menu-only implementation. An in-app language picker that
  stays in sync with this system setting can be added later via Android's
  `LocaleManager` (API 33+) exposed through a method channel.
- `minSdkVersion` is `flutter.minSdkVersion`; the system App Language menu only
  exists on API 33+, which is governed by the device — no extra handling is
  required for older API levels (the menu simply does not appear there).
