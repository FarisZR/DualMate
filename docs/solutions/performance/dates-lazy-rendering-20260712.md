---
title: Scale Dates rendering without regressing normal sections
date: 2026-07-12
type: fix
---

# Summary

The Dates page had two scaling problems:

- Rapla section cards eagerly built every event in a grouped section.
- The DH-Mine path built every `DataRow` inside an eager `DataTable` and
  `SingleChildScrollView`.

A first implementation flattened every Rapla section. Pixel profiling showed
that this added overhead for the common single-event sections used by the
fixture. The final implementation therefore uses a hybrid strategy: small
sections preserve their original one-card representation, while genuinely
large grouped sections are split into lazy rows.

# Changes

## Hybrid Rapla list

- Small sections containing at most four visible rows remain one list item and
  retain the original card, spacing, background, typography, and tap behavior.
- Larger grouped sections are flattened into individually lazy header/event
  rows with matching top, middle, and bottom decoration.
- The first populated item has a stable harness key independent of whether it
  is represented by a card or a lazy row.
- Deep list scrolling and pagination continue to use the existing controller
  and refresh behavior.

## Lazy DH-Mine table

- Replaced the eager `DataTable`/`SingleChildScrollView` combination with a
  `ListView.builder`.
- Preserved table margins, date/time layout, strike-through state, taps, and
  long descriptions with bounded two-line wrapping.
- Column widths are calculated once per viewport rather than intrinsically for
  every row.

## Prepared render data

- Date and time strings, past-state flags, section grouping, and table widths
  are prepared in an immutable render snapshot.
- Snapshots are invalidated when source lists, locale, selected data key, or
  the next past-state boundary changes.
- A timer updates only when a visible item can change from future to past.

## Offstage-safe loading transition

Cached rows may become ready while Dates is still offstage after drawer
selection. The previous implicit switcher could finish its 200 ms exit before
the page became visible. The loading indicator now remains retained while
`TickerMode` is disabled and begins its fade only after the destination is
active. No data loading is delayed.

# Regression coverage

Tests cover:

- small sections remaining one card item;
- large grouped sections using lazy top/middle/bottom rows;
- lazy construction of long Rapla lists;
- lazy fixed-width DH-Mine rows and deep scrolling;
- long description wrapping;
- preformatted dates and past state;
- scroll-position preservation;
- loading completion while offstage, followed by visible overlap and fade;
- the updated performance-harness populated-content finder.

# Pixel 8 Pro results

Device conditions:

- Pixel 8 Pro in profile mode;
- 120 Hz display;
- Android animation scales at `1.0`;
- deterministic offline fixtures;
- three current-`v2` control runs and three final branch runs.

Median comparison:

| Scenario | Metric | Current `v2` | Final branch |
| --- | --- | ---: | ---: |
| Drawer → populated Dates | p95 | 18.96 ms | 16.57 ms |
| Drawer → populated Dates | p99 / worst | 36.67 ms | 31.12 ms |
| Drawer → populated Dates | frames >16.67 ms | 2 | 1 |
| Drawer → populated Dates | frames >33 ms | 1 | 0 |
| Dates list scroll | p95 | 8.90 ms | 9.69 ms |
| Dates list scroll | worst | 22.62 ms | 23.85 ms |
| Dates list scroll | frames >16.67 ms | 1 | 1 |

The ordinary fixture contains mostly single-event sections, so its scrolling
result is intentionally near-neutral rather than a large improvement. The
structural gain applies to long exam groups and DH-Mine datasets that previously
constructed all inner rows eagerly. All three final runs observed the required
Dates loading-to-rows animation progression; all three control runs missed it.

# Validation

- full `flutter analyze` during the branch review;
- `flutter test test/date_management` — 37 tests passed;
- three-run current-`v2` Pixel control;
- three-run final-branch Pixel diagnostic;
- all Dates final-state, scroll-progression, and loading-progression checks
  passed;
- no animation durations, fixture data, or performance thresholds were reduced.
