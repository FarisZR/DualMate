---
component: sentry_reporting
tags: [sentry, diagnostics, gdpr, google-play, privacy, performance]
---

# Sentry GDPR-safe observability

DualMate initializes Sentry only when `SENTRY_DSN` is provided through a Dart
define. Builds without a DSN do not start Sentry.

Sentry remains enabled for crash reporting and low-sample performance tracing.
Production tracing uses `tracesSampleRate = 0.1` so startup and route
performance remain observable. Auto session tracking is disabled; release-health
session metrics are not collected.

Collected data:

- Crash and non-fatal error events.
- Stack traces.
- App release, build, environment, and platform metadata.
- Device operating system and app runtime environment.
- Performance transactions and spans with generic names such as `startup`,
  `schedule`, `dualis`, `canteen`, and `schedule.refresh`.
- Sanitized breadcrumbs for navigation, app diagnostics, and performance
  checkpoints.
- Span error metadata limited to `errorType` and a scrubbed `errorMessage`.

Not collected:

- Screenshots.
- Session replay.
- Auto session tracking / release-health sessions.
- Default PII.
- Raw Sentry user identifiers.
- Raw errors attached to performance spans.
- Credentials, tokens, cookies, authorization headers, Rapla URLs, iCal URLs,
  Dualis usernames/passwords, grades, marks, course data, room data, schedule
  event titles/details, canteen payloads, schedule payloads, or raw route
  arguments.
- Custom logs in release builds.

Privacy controls:

- `beforeSend`, `beforeBreadcrumb`, and `beforeSendTransaction` are registered
  in `sentry_configuration.dart` for the installed Sentry Flutter SDK API.
- `sentry_scrubber.dart` removes user context, redacts URLs, drops request
  bodies/cookies, and replaces sensitive keys, sensitive values, embedded
  emails, embedded URLs, and token-like strings with `[redacted]`.
- `AppDiagnostics` sanitizes breadcrumbs, contexts, tags, and spans before they
  reach Sentry, so manually attached model objects are not serialized into
  diagnostics payloads. Raw errors are not attached to spans.
- `SentryNavigatorObserver` uses a route-name extractor that emits only stable
  generic route names and drops route arguments.
- User interaction breadcrumbs/tracing are disabled because widget labels and
  tapped content can expose schedule or grade details.
- Release builds do not print raw startup or schedule exceptions/stack traces;
  those debug logs are gated behind `kDebugMode`.
