---
title: Keep Dualis tables lazy through first-open and tab transitions
date: 2026-07-12
type: fix
---

# Summary

Dualis overview and exam results rendered every module and exam row inside
intrinsic `DataTable` trees. On the Pixel 8 Pro at 120 Hz, first-open and tab
switching therefore combined destination construction, intrinsic measurement,
and complete table layout in one interaction window.

This change replaces the eager tables with fixed-width lazy slivers while
preserving the existing page structure, loading placeholders, row grouping,
text wrapping, refresh behavior, and tab selection semantics.

# Changes

## Lazy overview modules

- Replaced the overview `SingleChildScrollView` and eager `DataTable` with a
  `CustomScrollView` and lazy `SliverList`.
- Module rows are built only near the viewport.
- Column widths are resolved once from the available page width rather than by
  intrinsic table measurement across every row.
- Module names retain bounded two-line wrapping and the original 48–72 px row
  height behavior.
- The stable `dualis_modules_ready_<count>` key remains available to the
  performance harness independent of the row implementation.

## Lazy exam results

- Replaced one eager `DataTable` per module with a lazy sequence of module
  headers and exam rows.
- Precomputed module start offsets allow direct item-to-module lookup without
  flattening all row widgets.
- Preserved module grouping, credits and grade alignment, 45–72 px exam row
  height, two-line exam names, semester labels, and grade-state text.
- Localized grade strings are prepared during build from the current
  localization context, so locale changes cannot leave stale labels.

## Lightweight sliver transitions

- Replaced `AnimatedSwitcher` layouts that retained two complete table trees
  with a single current sliver tree and a 200/220 ms fade.
- Sliver content is constructed in `build`, not `initState`, so inherited theme
  and localization dependencies are valid.
- Loading placeholders and populated content keep their existing public keys
  and duration behavior.

## Deferred tab persistence

- Bottom-navigation selection updates immediately.
- Preference persistence starts after the current frame and coalesces rapid
  selections to the latest page.
- A pending write still completes if the pager is disposed before the callback
  runs.

# Regression coverage

Tests cover:

- lazy construction of distant overview module rows;
- lazy construction of distant exam rows;
- long module and exam labels without overflow;
- loading placeholder to populated content transitions;
- stable populated-content readiness markers;
- immediate tab switching;
- deferred persistence after a frame;
- persistence when the pager is disposed;
- rapid-selection coalescing to the latest page;
- generic pager persistence coverage in the mirrored `test/ui` tree;
- content-key-only sliver fade restarts and a hittable overview tooltip target;
- absence of eager `DataTable` trees.

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
| Drawer → populated Dualis | frames > 8.33 ms | 23.53% | 22.86% |
| Drawer → populated Dualis | p95 | 18.79 ms | 16.54 ms |
| Drawer → populated Dualis | p99 / worst | 36.82 ms | 25.73 ms |
| Drawer → populated Dualis | frames > 16.67 ms | 3 | 2 |
| Drawer → populated Dualis | frames > 33 ms | 1 | 0 |
| Loaded result scroll | p95 | 6.71 ms | 6.84 ms |
| Loaded result scroll | worst | 8.52 ms | 9.76 ms |
| Loaded tab switch | median worst | 40.67 ms | 31.22 ms |
| Loaded tab switch | frames > 33 ms | 1 | 0 |

The result-scroll path remains effectively neutral because the current fixture
contains a modest number of visible rows. The structural benefit grows with
larger module and exam datasets because distant rows are no longer constructed
or intrinsically measured.

The tab-switch scenario contains only five measured frames, so its percentage
is highly sensitive to one frame. Tail latency and the >33 ms result are more
meaningful than that percentage.

# Validation

- full `flutter analyze`;
- `flutter test test/dualis test/ui/pager_widget_test.dart` — 37 tests passed after final review;
- three-run current-`v2` Pixel control;
- three-run final-branch Pixel diagnostic;
- all Dualis final-state, session-restore, and scroll-progression checks passed;
- no performance thresholds, fixture data, or animation durations were reduced.
