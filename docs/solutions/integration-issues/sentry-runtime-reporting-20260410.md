---
module: App
date: 2026-04-10
problem_type: integration_issue
component: sentry_reporting
symptoms:
  - "Runtime errors were visible in logs but not consistently in Sentry"
  - "Local Android runs could miss Sentry init when no DSN define was provided"
root_cause: missing_runtime_reporting
resolution_type: code_fix
severity: high
tags: [sentry, diagnostics, android, logging, schedule]
---

# Sentry runtime reporting

## Overview
Sentry is wired through a small diagnostics layer instead of being called directly from feature code.

## Implementation

### Startup
- `lib/main.dart` initializes Sentry only when `isSentryConfigured()` returns true.
- `lib/common/logging/sentry_configuration.dart` resolves DSN, release, and environment from `String.fromEnvironment`.
- The same file falls back to a built-in DSN so local Android runs still report.

### Diagnostics seam
- `lib/common/logging/app_diagnostics.dart` wraps Sentry breadcrumbs, spans, and exception capture.
- `lib/common/logging/crash_reporting.dart` exposes `reportException(...)` as the shared entry point.
- Feature code calls `reportException(...)` or `AppDiagnostics.instance.reportCaughtException(...)`.

### Schedule errors
- `lib/schedule/business/schedule_provider.dart` reports every entry in `ScheduleQueryResult.errors`.
- Parse failures become `StateError('Schedule parse error: ...')` with the original trace.
- This makes UI-visible schedule parsing problems show up in Sentry.

### Other runtime paths
- Background refreshes, canteen prewarm, widgets, onboarding, and notification helpers also report caught failures through the same seam.

## Verification
On device, opening the January 2026 schedule reproduced `Parse exception: Invalid time format`.

Logcat showed:
- `Exception: Bad state: Schedule parse error: Parse exception: Invalid time format`
- `Sentry beforeSend: eventId=... throwable=Bad state: Schedule parse error: Parse exception: Invalid time format`
- `Envelope sent successfully.`

A separate canteen prewarm `Http request failed!` was also captured in Sentry.

## Related files
- `lib/main.dart`
- `lib/common/logging/sentry_configuration.dart`
- `lib/common/logging/app_diagnostics.dart`
- `lib/common/logging/crash_reporting.dart`
- `lib/schedule/business/schedule_provider.dart`
- `pubspec.yaml`
