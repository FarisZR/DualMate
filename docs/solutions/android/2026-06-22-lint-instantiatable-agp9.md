---
title: Fix lintVitalRelease Instantiatable false positive on AGP 9
date: 2026-06-22
category: android
---

## Problem

`flutter build appbundle --release` failed during the `lintVitalRelease`
Gradle task with:

```
MainActivity must extend android.app.Activity [Instantiatable]
```

`MainActivity` extends `io.flutter.embedding.android.FlutterActivity`,
which in turn extends `android.app.Activity`. Under AGP 9, lint cannot
resolve the Flutter embedding class hierarchy during release lint
analysis, producing a false positive that blocks the bundle build.

## Solution

Scoped the `Instantiatable` suppression to the specific `<activity>`
element using `tools:ignore` in `AndroidManifest.xml` rather than
disabling the check module-wide:

```xml
<activity
    android:name=".MainActivity"
    ...
    tools:ignore="Instantiatable">
```

This is a false positive because `MainActivity` extends
`FlutterActivity` → `android.app.Activity`; the check only fails because
AGP 9 lint cannot resolve the Flutter embedding artifact during
`lintVitalRelease`. Remove the `tools:ignore` when AGP fixes Flutter
embedding class resolution.

## Affected files

- `android/app/src/main/AndroidManifest.xml`

## Verification

- `flutter build appbundle --release` now passes `lintVitalRelease`
  (subsequent `signReleaseBundle` requires the release keystore, which is
  environment-specific and unrelated to this fix).
- `./gradlew :app:cleanLintVitalRelease :app:lintVitalRelease` →
  `BUILD SUCCESSFUL`.
