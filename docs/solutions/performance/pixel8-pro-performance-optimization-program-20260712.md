---
title: Pixel 8 Pro performance optimization audit and implementation program
date: 2026-07-12
type: fix
---

# Purpose

This document records the July 2026 performance optimization program that
followed the introduction of the loaded cold-navigation performance harness.
It explains:

- how the app was audited;
- how performance measurements were kept valid;
- which hotspots were identified;
- which architectural changes were applied;
- which approaches were rejected after profiling;
- how the final PR set was validated together;
- which hotspots remain for future work.

The work was intentionally constrained to invisible implementation changes.
Animations, gestures, shadows, overlays, page structure, and user-facing
behavior were preserved unless a change was required to keep the same behavior
correctly observable. The goal was to reduce build, layout, state, and raster
work rather than make the app appear faster by shortening or removing motion.

# Scope and merged changes

The program was implemented in the following order:

1. PR #96: stable weekly Schedule viewport rendering;
2. PR #97: stable Canteen shell and transitions;
3. PR #98: scalable Dates rendering;
4. PR #99: lazy Dualis tables;
5. PR #101: interaction-aware navigation and startup preparation;
6. PR #102: Schedule state coalescing and raster-layer isolation.

PRs #97, #98, #99, #101, and #102 were merged into `v2` in that order. PR #101
was stacked on PR #97 because it extends the Canteen initialization lifecycle.
PR #102 was stacked on PR #101 because it extends the same Schedule and startup
state model.

The resulting `v2` tree was compared with the locally tested integration branch
and the Git trees were identical.

# Audit methodology

## 1. Use a constrained low-end rendering proxy

The Pixel 8 Pro was treated as the primary weak-GPU/high-refresh stress device.
Although its CPU is not generally low-end, its behavior in this app exposed
raster and composition costs that were not visible on the Galaxy S21+.

The original device comparison showed that the same aggressive journey was much
worse on the Pixel:

| Metric | Pixel 8 Pro | Galaxy S21+ |
| --- | ---: | ---: |
| Frames over 8.33 ms | about 10.3% | about 0.8% |
| Frames over 16.67 ms | 18 | 1 |
| Frames over 33 ms | 2 | 0 |
| Worst frame | about 59.3 ms | about 29.5 ms |

The important lesson was that passing a 60 Hz budget was not sufficient. At
120 Hz, the relevant frame budget is approximately 8.33 ms.

## 2. Keep device conditions controlled

Performance comparisons used:

- Pixel 8 Pro connected over ADB;
- profile mode, not debug mode;
- forced 120 Hz during measurement;
- all Android animation scales set to `1.0`;
- deterministic offline fixture data;
- minimum display brightness to reduce heat and burn-in risk;
- repeated runs, normally three per candidate;
- medians rather than one best run.

The phone's normal settings were restored after measurement or before manual
use. The final user-facing build used the real `com.fariszr.dualmate` package,
not the benchmark fixture package.

## 3. Measure real interactions

The harness uses real gesture input for the important scenarios. It does not
replace user swipes with direct controller calls for the primary measurement.
Measured journeys include:

- opening and closing the drawer;
- cold navigation to Canteen, Dates, and Dualis;
- Schedule week swipes;
- short-to-tall Schedule viewport animation;
- memory-cached, database-cached, and refresh-required Schedule navigation;
- four rapid Schedule swipes;
- Canteen day swipes and varied meal-count transitions;
- Dates list scrolling;
- Dualis result scrolling and tab switching.

## 4. Verify behavior as well as frame timing

A low frame count is not considered valid if the app skipped the animation or
failed to reach the expected state. The harness therefore validates:

- final selected page/week/day;
- progressive intermediate animation state;
- loading-to-content overlap;
- real page progression during rapid swipes;
- nonzero attributed frames;
- absence of stale destination content;
- cache and refresh path identity.

A scenario is invalid if it reaches no measurable frames, jumps directly from
initial to final state when animation is expected, or fails its final-state
check.

## 5. Attribute frames by timestamp

Frame timings are assigned to scenarios using wall-clock timestamp ranges. The
harness drains delayed frame timing delivery after each scenario and assigns
only frames whose timestamps fall within that scenario's interval. This avoids
incorrect list-position slicing and prevents frames from adjacent interactions
from being counted in the wrong scenario.

## 6. Separate ranking and diagnosis

The profiling process used two levels:

- low-overhead ranking runs to identify the most severe scenarios;
- diagnostic runs with VM timeline traces for selected hotspots.

The ranking criteria include:

- percentage of frames over the active refresh-rate budget;
- p95 and p99 frame duration;
- worst frame;
- consecutive missed frames;
- frames over 16.67 ms and 33 ms;
- validity and animation-progression status.

## 7. Review code and results together

Each optimization was reviewed against both code structure and device data.
Passing tests alone was not enough, and a lower average was not enough if tail
latency, animation progression, or another page regressed.

The review loop was:

1. inspect the current render/state path;
2. identify the repeated or overlapping work;
3. add or update regression tests;
4. implement the smallest structural change;
5. run targeted tests and analyzer;
6. run repeated Pixel profiles;
7. compare medians with a fresh control;
8. reject or revise regressions;
9. run full feature tests;
10. address independent CodeRabbit review;
11. merge all PRs locally and run the complete suite and device journey.

# Cross-cutting findings

The audit found the same classes of problems across several features.

## Unstable render trees

Pages often replaced one large subtree with another during loading or
transition state. This caused outgoing and incoming scrollables, tables, or
cards to overlap while both were being laid out and painted.

Examples included:

- Canteen replacing a temporary loading body with a full pager;
- Schedule rebuilding its pager and cards during hour-range animation;
- Dualis switching between complete eager table trees;
- loading indicators finishing offstage before the destination became visible.

## Eager construction

Dates and Dualis built rows that were far outside the viewport. Intrinsic table
layout amplified this cost because every row participated in width and height
measurement.

## Repeated data preparation during build

Several render paths regrouped, sorted, filtered, formatted, or searched the
same data on every build or animation tick.

Examples included:

- Schedule overlap-column calculation;
- Canteen meal filtering and visible-day scanning;
- Dates grouping and date formatting;
- repeated state-object replacement with equivalent Schedule content.

## Over-broad notifications

View models emitted multiple notifications for one logical state change, or
published equivalent cache/refresh results. Root consumers then rebuilt large
page sections for changes that only affected one small child.

## Background work competing with interaction

Fixed startup timers and cold destination initialization could begin while a
drawer, swipe, route transition, or scroll was active. A first attempted global
"any Flutter animation means busy" heuristic was rejected because an
indeterminate loading spinner could prevent idle work forever.

## Stale asynchronous results

Cache reads and refresh requests could finish after the selected week, source,
or destination had changed. Without generation and request checks, old results
could still notify the visible page.

## Raster invalidation larger than necessary

The Schedule grid, entries, labels, current-time indicator, and translucent past
overlay did not share the same invalidation inputs, but parts of the tree were
painted together. This limited reuse of stable content during viewport changes.

# Implemented fixes

## Weekly Schedule: stable viewport and entry tree

PR #96 removed the largest build-side Schedule cost.

- `ScheduleRenderData` prepares displayed days, grouped entries, and overlap
  columns once per schedule snapshot.
- The PageView remains mounted while the hour range animates.
- Only the visible week listens to viewport animation ticks.
- Offscreen weeks use the final target viewport immediately.
- Entry cards remain the same widget instances during the animation.
- `CustomMultiChildLayout` updates entry rectangles without reconstructing card
  contents.
- Render-cache validation detects in-place `Schedule.entries` mutations.
- Fine-grained telemetry work was removed from the page item builder.

Representative result:

- first populated swipe frames over 8.33 ms: 25.00% to 14.58%;
- build frames over 8.33 ms: 18.18% to 4.08%;
- consecutive misses: 6 to 2.

See
[`weekly-schedule-stable-viewport-rendering-20260712.md`](weekly-schedule-stable-viewport-rendering-20260712.md).

## Canteen: stable shell, scoped consumers, and retained transitions

PR #97 made loading, paging, filtering, and meal-count changes operate inside
one stable page shell.

- The PageView exists from the first frame, including the fallback/loading day.
- Header, filter, pager, and day content use separate property consumers.
- One day owns one scrollable; loading, empty, and meal content are items inside
  that scrollable.
- A lightweight shell overlay retains the loading transition when data becomes
  ready while the destination is offstage.
- `CanteenWeekRenderState` and `CanteenDayContentState` provide immutable,
  selector-friendly snapshots.
- Filtered meals and visible content days are cached and invalidated by week.
- Week loading emits coalesced meaningful notifications.

Representative result:

- drawer-to-Canteen frames over 8.33 ms: roughly 25.5% to roughly 14–15%;
- settled repeated Canteen interaction: 0% over budget in the final focused run.

See
[`canteen-stable-render-shell-20260712.md`](canteen-stable-render-shell-20260712.md).

## Dates: hybrid lazy rendering

PR #98 addressed large grouped sections and DH-Mine tables without penalizing
the common small-section case.

- Small sections remain one original card item.
- Only large sections are split into lazy top/middle/bottom rows.
- DH-Mine uses fixed-width lazy rows instead of eager `DataTable` layout.
- Date strings, grouping, widths, and past-state boundaries are prepared in an
  immutable snapshot.
- The loading indicator is retained while offstage and begins its fade only
  when the page is visible.

A fully flattened first attempt was rejected because it made the common
single-event fixture slower. The hybrid version retained ordinary behavior and
improved cold-navigation tail latency while scaling correctly for large groups.

Representative result:

- drawer-to-Dates p99/worst: 36.67 ms to 31.12 ms;
- frames over 33 ms: 1 to 0;
- all final runs observed the required loading-to-rows progression.

See
[`dates-lazy-rendering-20260712.md`](dates-lazy-rendering-20260712.md).

## Dualis: lazy fixed-width slivers

PR #99 removed eager intrinsic table layout from overview and exam results.

- Overview modules use a lazy `SliverList`.
- Exam modules and rows use a lazy indexed sequence.
- Widths are resolved once from the viewport.
- Existing row grouping, credits, grades, wrapping, and heights are preserved.
- Localized content is built from the current context rather than cached from
  `initState`.
- Loading/content transitions fade one current sliver tree instead of retaining
  two complete tables.
- Tab persistence is deferred, coalesced, and still completes on disposal.

Representative result:

- drawer-to-Dualis p99/worst: 36.82 ms to 25.73 ms;
- frames over 33 ms: 1 to 0;
- tab-switch median worst frame: 40.67 ms to 31.22 ms.

See
[`dualis-lazy-table-rendering-20260712.md`](dualis-lazy-table-rendering-20260712.md).

## Navigation and startup: explicit interaction-aware idle work

PR #101 prevents cache and startup work from competing with visible
interactions.

- `InteractionIdleCoordinator` serializes deferred tasks in FIFO order.
- Task IDs deduplicate equivalent work.
- Explicit leases cover pointer, scroll, drawer, and route transitions.
- Navigation waits for one interaction-free frame.
- Background tasks additionally wait through a 180 ms quiet period.
- A clean frame separates serial tasks.
- Repeating spinners do not block the queue.
- Navigation preparation is separated from widget activation.
- Destination activation never waits for network work.
- Preparation is cache/local-only:
  - Schedule reads the visible cache;
  - Canteen reads location and current-week cache without refresh;
  - Dates reads preferences;
  - Dualis restoration remains visibility-owned.
- Late preparation cannot regress an already active entry lifecycle.

Representative result:

- drawer-to-Canteen frames over 8.33 ms: 25.00% to 13.33%;
- drawer-to-Canteen p95: 25.48 ms to 10.21 ms;
- drawer-to-Dualis frames over 8.33 ms: 23.53% to 10.81%;
- drawer-to-Dualis p99/worst: 36.82 ms to 19.89 ms.

See
[`interaction-aware-cold-navigation-preparation-20260712.md`](interaction-aware-cold-navigation-preparation-20260712.md).

## Schedule state and raster follow-up

PR #102 addressed the remaining state churn and paint invalidation after the
stable viewport work.

- `VisibleWeeklyScheduleSnapshot` compares render-relevant immutable content.
- Equivalent cache and refresh results do not notify the page.
- Source generations and visible request IDs reject stale results.
- While paging, only the latest valid result for the settled week is applied.
- Adjacent prefetch updates caches without replacing visible state.
- Static vertical grid lines are separated from viewport-dependent hour lines.
- Grid, stable entries, labels, past overlay, and current-time indicator have
  targeted repaint boundaries.
- Frame diagnostics use the active refresh-rate budget in microseconds and keep
  sub-millisecond precision.

Representative result:

- settled populated swipe frames over 8.33 ms: 22.92% to 12.24%;
- database-cached navigation frames over 8.33 ms: 17.95% to 7.20%;
- rapid four-swipe burst frames over 8.33 ms: 16.45% to 7.45%;
- rapid burst p95: 16.00 ms to 9.89 ms.

See
[`weekly-schedule-state-raster-refresh-20260712.md`](weekly-schedule-state-raster-refresh-20260712.md).

# Rejected or revised approaches

The following attempts were not accepted unchanged.

## Rebuilding only the visible Schedule page

Caching alignment and rebuilding only the visible page reduced some work, but
entry cards still reconstructed on every viewport tick. The final design keeps
card subtrees stable and relayouts only their rectangles.

## Identity-only Schedule render caching

A first cache reused prepared data by `Schedule` object identity. Because
`Schedule.entries` is publicly mutable, this could display stale geometry. The
final cache validates the exact entry identity/order sequence and has direct
mutation regression coverage.

## Fully flattened Dates sections

Flattening every section introduced overhead for the common single-event case.
Pixel profiling showed a net regression. The final hybrid strategy keeps small
sections as original cards and lazily splits only larger groups.

## Global animation-based idle detection

Using Flutter's global transient callback count treated any spinner as active
interaction. An indeterminate loading animation could starve preparation
forever. The final coordinator uses explicit interaction leases and a bounded
quiet period.

## Blocking activation on preparation

Awaiting preparation before mounting a destination could make navigation depend
on cache or network latency. The final lifecycle starts preparation
opportunistically but never blocks destination activation.

## Broad repaint boundaries

The Schedule follow-up did not wrap the whole page in additional layers. Only
subtrees with independent invalidation inputs received boundaries. Each boundary
was retained only after combined frame timing improved in repeated Pixel runs.

## Implicit offstage switchers

Canteen and Dates could complete their switcher animations while offstage,
leaving no visible loading-to-content overlap when the page appeared. The final
transitions explicitly retain outgoing loading state until `TickerMode` is
active.

# Test and review coverage

## Automated tests

The final locally merged integration branch passed:

- full `flutter analyze`;
- all 440 Flutter tests across the repository.

The feature-specific suites included:

- Schedule viewport, entry identity, cache, refresh, stale-result, paging,
  repaint-boundary, and telemetry tests;
- Canteen render-state, loading, paging, filtering, location, and transition
  tests;
- Dates small/large section, lazy row, DH-Mine, wrapping, timing, and offstage
  transition tests;
- Dualis lazy construction, localization, overflow, transition, tooltip, and
  pager persistence tests;
- navigation coordinator, quiet period, spinner non-starvation, scroll lease,
  cache-only preparation, activation, and lifecycle tests.

## Device validation

The final integration branch ran the complete diagnostic journey three times on
the Pixel 8 Pro. Each run contained 21 measured scenarios.

Across all three runs:

- no scenario was invalid;
- no final-state check failed;
- no animation-progression check failed;
- no animation was dropped;
- no diagnostic warning remained.

The real, non-fixture profile APK was then installed over the existing app and
manually checked for visible regressions before merge.

## Independent review

Every PR was reviewed by CodeRabbit. Valid findings included:

- mutable render-cache invalidation;
- test-hook cleanup;
- notifier changes during build;
- normalized week keys;
- loading-state construction and copy contracts;
- offstage transition behavior;
- localized content construction;
- generic pager test placement;
- tooltip hit target size;
- content-key-only fade restarts;
- late lifecycle regression;
- initial quiet-period semantics;
- cache-only Schedule preparation;
- telemetry precision and non-positive refresh-rate handling.

All review threads were resolved before merge. The final PRs were approved,
mergeable, and CI-green.

# Final integrated profile snapshot

The final merged implementation is substantially smoother than the original
Pixel baseline, but 120 Hz remains a strict target. The final three-run summary
still ranked these scenarios as the most expensive:

| Scenario | Frames over 8.33 ms | p99 / worst |
| --- | ---: | ---: |
| Drawer cold open over populated Schedule | 24.00% | 35.23 ms |
| Dualis loaded tab switch | 20.00% | 23.82 ms |
| Schedule short-to-tall transition | 18.18% | 18.68 ms |
| Schedule cold placeholder to populated | 16.67% | 40.88 ms |
| Drawer to populated Dualis | 15.38% | 22.82 ms |
| Schedule first populated swipe | 14.00% | 25.38 ms |
| Drawer to populated Canteen | 11.11% | 51.55 ms |
| Schedule settled populated swipe | 12.24% | 19.21 ms |
| Drawer to populated Dates | 11.54% | 25.84 ms |
| Schedule rapid four-swipe burst | 9.49% | 20.43 ms |

These numbers should be treated as prioritization data, not as evidence that the
program failed. Several scenarios contain few frames, so one frame can move the
percentage significantly. Tail latency, consecutive misses, progression checks,
and repeated medians should be considered together.

# Remaining work

## 1. Drawer cold-open composition

Opening the drawer over a populated Schedule remains the highest missed-frame
percentage. Future work should trace:

- drawer scrim composition;
- Schedule layer invalidation while the drawer animates;
- whether the underlying Schedule is repainted unnecessarily;
- platform view/window composition behavior;
- shader or first-use costs on the drawer path.

Do not solve this by shortening the drawer animation. Confirm build versus raster
cost with a timeline first.

## 2. Canteen cold-navigation tail spikes

The average and percentage improved substantially, but occasional 40–50 ms tail
frames remain. Investigate:

- first text/layout/shader work for meal cards;
- image/icon/font first use;
- stable shell overlay composition;
- initial visible-day list materialization;
- whether provider callbacks coincide with the first destination frame.

## 3. Schedule cold population

Initial placeholder-to-populated rendering still has a high worst frame because
the complete visible entry tree must be constructed once. Possible follow-up
areas:

- staged first population without changing visible semantics;
- precomputing text/layout inputs off the interaction path;
- warming common paragraph/font/shader paths;
- applying only visible-day/card work before offscreen content;
- verifying whether database decode or widget construction dominates.

## 4. Short-to-tall Schedule raster cost

Combined timing improved, but the raster-only over-budget percentage increased
in the focused branch comparison. Future work should inspect:

- translucent past overlay repaint area;
- grid line cacheability;
- card shadow and clipping layers;
- whether entry boundaries are retained or recreated during geometry changes;
- GPU overdraw at the largest hour-height change.

Do not add more repaint boundaries without measuring layer count and raster
effect. Extra layers can make weak GPUs worse.

## 5. Dualis tab-switch sample size

The tab-switch scenario contains very few frames, making percentages unstable.
Add a repeated tab-switch stress scenario or a longer interaction window before
making another structural change. Preserve immediate selection and deferred
persistence behavior.

## 6. Larger realistic data fixtures

Current deterministic fixtures validate behavior and common workloads, but
future harness expansion should include:

- very large Dates groups;
- larger DH-Mine datasets;
- more Dualis modules and exams;
- dense overlapping Schedule days;
- Canteen days with long names, notes, allergens, and many meals.

Use separate scale-focused scenarios so larger fixtures do not silently change
existing baseline semantics.

## 7. Thermal and device matrix validation

Continue using the Pixel 8 Pro as the weak-raster proxy, but add at least one
lower-end 60 Hz device and one modern mid-range 90/120 Hz device. Record:

- refresh rate;
- thermal state;
- display resolution;
- renderer/backend;
- animation scales;
- build mode;
- app version and commit;
- whether the run was cold or warm.

# Rules for future performance work

1. Keep user-visible behavior and animation duration unchanged unless product
   requirements explicitly change.
2. Use profile mode on physical hardware.
3. Use the active refresh-rate budget, not a fixed 16 ms threshold.
4. Run at least three comparable measurements and report medians.
5. Validate final state and intermediate animation progression.
6. Prefer stable trees, immutable render snapshots, selector-scoped rebuilds,
   and lazy construction before adding micro-optimizations.
7. Keep preparation cache-only and never block navigation on network work.
8. Reject stale async results using source generation and request identity.
9. Add repaint boundaries only around independently invalidated layers and keep
   them only when raster measurements improve.
10. Do not weaken fixtures, thresholds, gestures, or animation checks to make a
    result pass.
11. Compare the full integrated branch, not only isolated feature branches.
12. Record rejected approaches so future work does not repeat known regressions.

# Related documents

- [`offline-cold-navigation-performance-harness.md`](offline-cold-navigation-performance-harness.md)
- [`weekly-schedule-stable-viewport-rendering-20260712.md`](weekly-schedule-stable-viewport-rendering-20260712.md)
- [`canteen-stable-render-shell-20260712.md`](canteen-stable-render-shell-20260712.md)
- [`dates-lazy-rendering-20260712.md`](dates-lazy-rendering-20260712.md)
- [`dualis-lazy-table-rendering-20260712.md`](dualis-lazy-table-rendering-20260712.md)
- [`interaction-aware-cold-navigation-preparation-20260712.md`](interaction-aware-cold-navigation-preparation-20260712.md)
- [`weekly-schedule-state-raster-refresh-20260712.md`](weekly-schedule-state-raster-refresh-20260712.md)
