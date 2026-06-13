---
component: sentry_reporting
tags: [sentry, diagnostics, gdpr, google-play, privacy, performance]
---

# Sentry GDPR-safe observability

DualMate initializes Sentry only when `SENTRY_DSN` is provided through a Dart
define. Builds without a DSN do not start Sentry.

Sentry remains enabled for crash reporting and low-sample performance tracing.
Production tracing uses `tracesSampleRate = 0.1` so startup and route
performance remain observable without capturing every session.

Collected data:

- Crash and non-fatal error events.
- Stack traces.
- App release, build, environment, and platform metadata.
- Device operating system and app runtime environment.
- Performance transactions and spans with generic names such as `startup`,
  `schedule`, `dualis`, `canteen`, and `schedule.refresh`.
- Sanitized breadcrumbs for navigation, app diagnostics, and performance
  checkpoints.

Not collected:

- Screenshots.
- Session replay.
- Default PII.
- Raw Sentry user identifiers.
- Credentials, tokens, cookies, authorization headers, Rapla URLs, iCal URLs,
  Dualis usernames/passwords, grades, marks, course data, room data, schedule
  event titles/details, canteen payloads, schedule payloads, or raw route
  arguments.
- Custom logs in release builds.

Privacy controls:

- `beforeSend`, `beforeBreadcrumb`, and `beforeSendTransaction` are registered
  in `sentry_configuration.dart` for the installed Sentry Flutter SDK API.
- `sentry_scrubber.dart` removes user context, strips URL query strings, drops
  request bodies/cookies, and replaces sensitive keys or values with
  `[redacted]`.
- `AppDiagnostics` sanitizes breadcrumbs, contexts, tags, spans, and attached
  exceptions before they reach Sentry, so manually attached model objects are
  not serialized into diagnostics payloads.
- `SentryNavigatorObserver` uses a route-name extractor that emits only stable
  generic route names and drops route arguments.
- User interaction breadcrumbs/tracing are disabled because widget labels and
  tapped content can expose schedule or grade details.
