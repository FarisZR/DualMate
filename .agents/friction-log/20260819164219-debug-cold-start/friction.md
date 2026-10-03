---
title: 'Debug cold start asserts while building ScheduleViewModel provider'
severity: 'major'
issue: 'FarisZR/DualMate#128'
---

## Expected Behavior

The isolated debug APK starts without Flutter framework assertions.

## Current Behavior

A physical-device debug cold start repeatedly logs a widgets assertion while building ChangeNotifierProvider<ScheduleViewModel> at lib/ui/navigation/navigation_entry.dart:56. The assertion is package:flutter/src/widgets/framework.dart line 5538: !_dirty.

## Possible Solution

Audit startup rebuilds and notifications around NavigationEntry and the ScheduleViewModel provider. This was found during an unrelated Dualis validation and should be fixed separately.

## Minimal Reproducible Example

1. Run flutter build apk --debug --dart-define=PERF_TEST_OFFLINE_FIXTURES=true.
2. Run android run --apks=build/app/outputs/flutter-apk/app-debug.apk --device=RFCR31468LJ.
3. Inspect adb logcat during cold startup.
4. Observe the assertion in two fresh com.fariszr.dualmate.perf processes.

## Context

Device: Samsung SM-G996B, serial RFCR31468LJ. The app remains visible behind the exact-alarm prompt, but startup logs contain the assertion and Sentry captures it. No Schedule code was modified in the Dualis loading-state fix.
