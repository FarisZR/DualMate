---
module: Schedule
date: 2026-04-10
problem_type: integration_issue
component: sentry_reporting
symptoms:
  - "Schedule page showed an incomplete-schedule warning, but no matching Sentry error was visible"
  - "Local Android runs without an explicit SENTRY_DSN define did not reliably initialize Sentry"
root_cause: missing_runtime_reporting
resolution_type: code_fix
severity: high
tags: [sentry, schedule, rapla, parse-error, android, diagnostics]
---

# Troubleshooting: Sentry missed Rapla schedule parse errors

## Problem
The January 2026 Rapla schedule could reproduce `Parse exception: Invalid time format` on device, and the schedule UI showed the incomplete-schedule warning, but the same failure was not initially visible in Sentry.

## Solution
Keep Sentry initialized for local/device Android runs by falling back to the configured default DSN when no `SENTRY_DSN` define is passed.

Forward non-fatal Rapla parser failures from `ScheduleQueryResult.errors` through `reportException(...)` in `ScheduleProvider.getUpdatedSchedule(...)` so UI-visible schedule parse problems become Sentry events.

## Verification
Verified on a real Android device with the Rapla source configured to `TINF25B4` and the schedule opened to `26 Jan - 1 Feb 2026`.

Logcat showed the full flow:
- `Exception: Bad state: Schedule parse error: Parse exception: Invalid time format`
- `Sentry beforeSend: eventId=... throwable=Bad state: Schedule parse error: Parse exception: Invalid time format`
- `Envelope sent successfully.`

Sentry also captured a separate canteen prewarm `Http request failed!` event in the same run, confirming general runtime reporting was active.
