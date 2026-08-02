---
title: "Keep localrelease opt-in for production release builds"
category: developer-experience
date: 2026-08-02
---

# Keep localrelease opt-in for production release builds

## Problem

The `localrelease` Android flavor was registered for every Gradle invocation.
Flutter's flavorless release commands therefore produced flavored output such
as `app-localrelease-release.apk`, which the release workflow did not find.
The same issue prevented the later Play Store AAB step from running.

## Solution

Only register the `localrelease` flavor when the requested Gradle task contains
`localrelease`. Normal flavorless builds keep the standard variants and output
paths:

- debug builds use the Android debug key;
- `--flavor localrelease --release` or `--flavor localrelease --profile` uses
  the local debug key for local testing;
- flavorless release APK/AAB builds use `android/key.properties`, which the
  release workflow populates from the Google Play signing secrets.

The release workflow also passes `--release` explicitly for the APK build.

## Verification

- Verify a flavorless debug build produces `app-debug.apk`.
- Verify `--flavor localrelease --release` produces
  `app-localrelease-release.apk`.
- Verify the release workflow's flavorless commands target
  `app-arm64-v8a-release.apk` and `bundle/release/app-release.aab`.
