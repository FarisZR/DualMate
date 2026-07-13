---
title: Pin Dualis sessions across multi-request operations
date: 2026-07-13
type: fix
---

# Summary

Sentry issue DUALMATE-10 (`133984052`) reported a fatal
`LateInitializationError` from `DualisAuthentication.authenticatedGet` while a
semester was loading. The failure was caused by a mutable demo-account scraper
delegate changing between the semester module request and its follow-up exam
requests.

# Root cause

`FakeAccountDualisScraperDecorator` selected either the local demo scraper or
the real network scraper through a mutable delegate. `DualisServiceImpl` made a
semester query through several independent decorator calls:

1. load the semester's modules;
2. load the exams for every module.

If onboarding or schedule-source setup changed the decorator selection between
those calls, the remaining exam requests were sent to the real scraper. That
scraper had not logged in, so its `late Session` field was uninitialized and the
request crashed.

The schedule source and grade service also shared one scraper singleton, which
allowed otherwise independent workflows to change the same authentication
state.

# Fix

- Capture the selected scraper once at the start of each high-level Dualis read
  operation and reuse it for every request in that operation.
- Apply the same operation snapshot to multi-month Dualis schedule queries.
- Give the schedule source and grade service separate scraper/session instances.
- Replace unsafe `late` authentication lifecycle fields with explicit nullable
  state and clear errors for invalid unauthenticated calls.
- Preserve the existing concurrent grade, module, and semester-name refreshes;
  no global request serialization was added.

# Regression coverage

- A deterministic test switches the decorator from demo to real credentials
  while `querySemester` is between module and exam requests. All requests remain
  on the captured demo scraper.
- Authentication tests cover unauthenticated requests, logout-before-login, and
  missing previous credentials.
- A view-model test verifies the three refresh branches still reach a maximum
  concurrency of three.
- All Dualis tests and `flutter analyze` pass.

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
normal device-run variance rather than a systematic regression. No
performance thresholds, fixtures, animation durations, refresh concurrency, or
measurement windows
were changed.
