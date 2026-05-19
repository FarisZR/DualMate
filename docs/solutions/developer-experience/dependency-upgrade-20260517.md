---
module: Developer Experience
date: 2026-05-17
problem_type: developer_experience
component: dependency_management
symptoms:
  - "Locked Flutter packages had fallen behind current compatible releases"
  - "Tests needed rerunning after a broad dependency refresh"
root_cause: stale_dependencies
resolution_type: maintenance
severity: medium
tags: [dependencies, flutter, pub, android, maintenance]
---

# Dependency Upgrade Refresh

## Problem
The app's Flutter package lockfile had drifted behind the latest versions that are compatible with the current codebase and SDK constraints.

## Solution

1. Ran `flutter pub outdated --show-all` to identify direct and transitive updates.
2. Upgraded the machine Flutter SDK on stable to `3.41.9` / Dart `3.11.5`.
3. Upgraded the package graph with `flutter pub upgrade --major-versions`.
4. Updated explicit `pubspec.yaml` constraints for the direct packages that resolved to newer compatible versions.
5. Removed the direct `test` dependency and converted pure Dart tests to `flutter_test`, which eliminated the temporary `matcher` / `test_api` / `test_core` override stack.
6. Replaced the temporary `path_provider_android` override with the upstream hosted package once the newer Flutter SDK resolved it cleanly.
7. Kept `flutter_local_notifications` on `^18.0.1` and `device_calendar` on the published `^4.3.3` release; bumped `timezone` to `^0.9.4` to satisfy both. Moving to `flutter_local_notifications 21.x` was evaluated but abandoned because `device_calendar 4.3.3` pins `timezone` to `^0.9.x`, which conflicts with the `^0.11.0` requirement of 21.x.
8. Updated `lib/common/ui/notification_api.dart` to use positional arguments to align with the `flutter_local_notifications 18.x` API (reverting an earlier attempt to migrate to the 21.x named-argument API).
9. Cleaned up Flutter deprecations in app and test code (`RadioGroup`, `WidgetTester.view`, `withValues`, theme construction, and view access helpers).
10. Revalidated the app with `flutter test` and scoped Flutter analysis.

## Notes
- The final project state no longer needs any `dependency_overrides` in the root `pubspec.yaml`.
- `flutter_local_notifications` remains on `^18.0.1` because upgrading to `21.x` would require `timezone ^0.11.0`, conflicting with the `timezone ^0.9.x` constraint of `device_calendar 4.3.3`.
- `flutter upgrade` can fail on this machine if `/tmp` is full because Flutter's tool update path writes pub downloads there first; rerun with extra temp capacity available if that happens again.
- Root-level `flutter analyze lib test` is clean on the upgraded SDK and dependency set.
