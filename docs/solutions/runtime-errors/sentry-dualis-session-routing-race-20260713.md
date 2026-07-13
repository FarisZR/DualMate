---
title: Harden Dualis session routing across multi-request operations
date: 2026-07-13
type: fix
---

# Summary

Sentry issue DUALMATE-10 (`133984052`) reported a fatal
`LateInitializationError` from `DualisAuthentication.authenticatedGet` while a
semester was loading.

The stack includes `FakeAccountDualisScraperDecorator` because every production
Dualis scraper is wrapped by that decorator. The next frames are
`DualisScraper` and `DualisAuthentication`, which show that the failing request
was routed to the real network scraper at the time of the crash. The event does
not include the credentials or enough lifecycle state to prove that the user
had selected the demo account.

# Confirmed risk

The schedule source and grade service shared one mutable scraper instance. That
instance owns both the selected decorator delegate and the real authentication
session. Independent schedule, onboarding, session-restoration, logout, and
grade-loading flows could therefore alter routing or authentication state used
by another in-flight operation.

A semester query also consists of several requests: one request loads modules,
then follow-up requests load each module's exams. Resolving the mutable
decorator for every request allowed one logical operation to cross scraper or
session boundaries if another flow changed that shared state.

The exact interleaving that produced the single Sentry event cannot be recovered
from the redacted event. The fix therefore targets the confirmed unsafe state
ownership rather than attributing the event to a specific account type.

# Fix

- Capture the active scraper once at the start of each high-level Dualis read
  operation and reuse it for every request in that operation.
- Apply the same operation snapshot to multi-month Dualis schedule queries.
- Give the schedule source and grade service separate scraper/session instances.
- Replace unsafe `late` authentication lifecycle fields with explicit nullable
  state and clear errors for invalid unauthenticated calls.
- Preserve the existing concurrent grade, module, and semester-name refreshes;
  no global request serialization was added.

# Regression coverage

- A deterministic test changes the decorator selection between a semester's
  module request and its exam request. The logical query remains on the scraper
  captured when the operation began.
- Authentication tests cover unauthenticated requests, logout-before-login, and
  missing previous credentials.
- A view-model test verifies the three refresh branches still reach a maximum
  concurrency of three.
- The full Flutter test suite and `flutter analyze` pass.

# Galaxy S21+ performance validation

The v2.1.0 offline cold-navigation harness was run in profile mode on the
connected Galaxy S21+ (`SM-G996B`, `RFCR31468LJ`) with animation scales at
`1.0`. Baseline and fixed builds each used three fresh-process Dualis runs.
All six runs reached the populated final state and passed the session-restore
check.

| Median metric | v2 baseline | Fixed branch |
| --- | ---: | ---: |
| Frames over 8.33 ms | 4 | 4 |
| Frames over 8.33 ms | 5.19% | 5.19% |
| Frames over 16.67 ms | 1 | 1 |
| Frames over 33 ms | 0 | 0 |
| Consecutive missed frames | 2 | 2 |
| Combined p95 | 5.294 ms | 6.720 ms |
| Combined p99 | 14.309 ms | 13.743 ms |
| Worst frame | 19.181 ms | 21.623 ms |

The percentile and worst-frame values varied between repeated three-run fixed
batches, while the frame-budget counts, longest missed-frame sequence, and
final-state validity remained unchanged. The final-tree batch improved p99 and
showed a 2.442 ms higher worst frame, still below the 33 ms budget; a preceding
fixed batch instead showed an improved worst frame. This is consistent with
normal device-run variance rather than a systematic regression. No performance
thresholds, fixtures, animation durations, refresh concurrency, or measurement
windows were changed.
