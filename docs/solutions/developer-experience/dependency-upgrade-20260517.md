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
2. Upgraded the package graph with `flutter pub upgrade --major-versions`.
3. Updated explicit `pubspec.yaml` constraints for the direct packages that resolved to newer compatible versions.
4. Updated the `win32` override to `^6.2.0` so the refreshed transitive graph remained compatible with `package_info_plus`.
5. Revalidated the app with `flutter test` and scoped Flutter analysis.

## Notes
- `flutter_local_notifications` could not move to `21.x` because it now requires `timezone ^0.11.0`, while `device_calendar 4.3.3` still requires `timezone ^0.9.0`.
- `test 1.31.x` is not currently resolvable because `flutter_test` from the Flutter SDK pins `test_api 0.7.9`.
- Root-level `flutter analyze` still reports errors in the vendored `third_party/path_provider_android/pigeons/messages.dart` file because that local override expects its own dev-only `pigeon` dependency. App code analysis remains clean when scoped to the main project sources.
