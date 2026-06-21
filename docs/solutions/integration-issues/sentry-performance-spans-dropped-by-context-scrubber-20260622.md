---
component: sentry_reporting
tags: [sentry, performance, tracing, flutter, android]
---

# Sentry performance spans dropped by context scrubber

## Symptom

Performance instrumentation appeared to run locally, but Sentry did not show
the app-generated transactions or spans. Android logcat showed repeated native
SDK failures:

```text
Failed to capture envelope
java.lang.IllegalArgumentException: Envelope contains no header.
```

## Cause

`scrubSentryEvent` is also called for `SentryTransaction` through
`beforeSendTransaction`. The context scrubber sanitized every non-whitelisted
context by assigning the sanitized value back into `Contexts`.

That corrupted typed SDK contexts such as `culture`, `browser`, `gpu`,
`response`, `feedback`, and feature flags by replacing them with strings. When
the Sentry SDK later serialized the transaction, `Contexts.toJson()` expected
typed context objects and failed. The transaction envelope item was skipped,
leaving malformed/empty transaction envelopes and no stored performance data.

## Fix

Keep all SDK-owned typed context keys structurally intact while continuing to
sanitize custom app contexts. The custom context path still redacts sensitive
payloads such as Dualis and schedule data.

Regression coverage:

- `beforeSend keeps typed Sentry contexts serializable`
- `flutter test test/common/logging`

## Verification

Verified on the connected Pixel 8 Pro with `flutter run -d 39181FDJG006DP`.
Logcat showed Sentry envelopes being added to offline storage and sent
successfully, with no `Envelope contains no header` failures for the patched
process.

Sentry CLI confirmed the phone-generated trace
`e4295cc1769a49fda23d0cde129cc4aa` stored transactions:

- `startup.initialize` (`460c785746434937bfacfbfa50e8b99d`)
- `root /` (`8631029082a8455091e5587c855a9a91`)
- `canteen.menu.parse` (`82d43de1481244968c94e7844b80d5eb`)

`sentry span list fariszr/dualmate/e4295cc1769a49fda23d0cde129cc4aa`
returned app spans including `schedule.remote.fetch`,
`schedule.remote.parse`, `schedule.cache.read`, `schedule.entries.filter`,
`schedule.state.apply`, and `schedule.list.build`.
