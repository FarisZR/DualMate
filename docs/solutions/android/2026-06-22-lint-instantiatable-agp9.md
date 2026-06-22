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

Disabled the `Instantiatable` lint check for the app module in
`android/app/build.gradle`. Also migrated the deprecated `lintOptions`
block to the modern `lint {}` DSL (AGP 9+ only reads the new DSL for
some options).

```groovy
android {
    lint {
        disable 'InvalidPackage'
        disable 'Instantiatable'
    }
}
```

`Instantiatable` is a false positive here because the activity class
hierarchy is valid; the check only fails because lint cannot see through
the Flutter embedding artifact.

## Affected files

- `android/app/build.gradle`

## Verification

- `flutter build appbundle --release` now passes `lintVitalRelease`
  (subsequent `signReleaseBundle` requires the release keystore, which is
  environment-specific and unrelated to this fix).
