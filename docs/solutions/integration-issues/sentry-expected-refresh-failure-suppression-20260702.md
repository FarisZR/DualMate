---
module: Diagnostics
date: 2026-07-02
problem_type: integration_issue
component: sentry_reporting
symptoms:
  - "Expected schedule and canteen HTTP/source failures appeared as noisy Sentry Issues"
  - "Schedule source connectivity suppression could be undone by later refresh catch blocks"
root_cause: expected_external_failures_reported_as_app_errors
resolution_type: code_fix
severity: medium
tags: [sentry, diagnostics, schedule, canteen, network]
---

# Sentry expected refresh failure suppression

## Problem
Schedule and canteen refreshes depend on external university/source services.
Temporary request failures are expected and are not actionable app bugs, but
several foreground, background, and startup refresh paths reported them through
Sentry. In schedule refreshes, source-level suppression could be undone by
later view-model catch blocks that called `reportException`.

## Solution
Expected external failures are now classified before they reach Sentry:

- `ExpectedExternalFailure` marks failures caused by external availability,
  connectivity, or cancellation.
- `DiagnosticExceptionWithCause` lets wrapper exceptions delegate suppression
  decisions to their inner cause.
- `AppDiagnostics.reportCaughtException` drops suppressible exceptions before
  capture.
- Schedule `ServiceRequestFailed` and canteen `CanteenRequestFailed` are
  suppressible.
- Schedule query wrappers suppress only when their inner cause is suppressible.

Performance spans keep coarse status data such as `network_error`, but
suppressible refresh failures are not attached as internal app errors.

## Suppressed
- Schedule `ServiceRequestFailed`.
- `ScheduleQueryFailedException` when caused by `ServiceRequestFailed`.
- Canteen HTTP/null-response failures represented by `CanteenRequestFailed`.
- `OperationCancelledException`.

## Still reported
- Schedule parser failures from `ScheduleQueryResult.errors`.
- Schedule query failures caused by parser/format errors.
- Canteen JSON decode or parser regressions.
- Cache, database, state, callback, and other unexpected app failures.

## Verification
Covered with focused tests for diagnostics filtering, schedule source/view-model
reporting behavior, and typed canteen request failures.
