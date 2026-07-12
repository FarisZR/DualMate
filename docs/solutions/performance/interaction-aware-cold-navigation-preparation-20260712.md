---
title: Prepare cold navigation sections during interaction-aware idle time
date: 2026-07-12
type: fix
---

# Summary

Cold drawer navigation previously protected the closing animation with a fixed
260 ms delay, but still created destination view models and started cache work in
the activation frame. Startup background tasks also used independent fixed
timers, so they could begin while the user was scrolling or opening a route.

This change separates local section preparation from widget activation and
serializes deferred startup work through an interaction-aware idle coordinator.
The existing drawer animation and delay remain unchanged.

# Interaction-aware idle coordinator

`InteractionIdleCoordinator` owns a FIFO queue for deferred work.

- Tasks run one at a time.
- Duplicate task IDs share the same queued task.
- Queued work waits while explicit pointer, scroll, drawer, or route-transition
  leases are active.
- After the last interaction ends, navigation idle waiters require one complete
  interaction-free frame. Background tasks additionally wait through a 180 ms
  quiet period so they do not immediately compete with the animation tail.
- A clean frame is also required between serialized tasks so several cache reads
  cannot start in the same frame.
- Unrelated repeating animations, such as indeterminate loading indicators, do
  not block the queue indefinitely.
- Queued tasks can be cancelled when their owner is disposed; already-running
  futures are allowed to complete safely.

# Section prepare and activate lifecycle

`NavigationEntry` now has distinct phases:

1. `prepare()` creates the section-owned view model and starts local preparation
   without mounting widgets.
2. `activate()` mounts the provider and route subtree.
3. The existing `IndexedStack` keeps activated sections alive as before.

Preparation is opportunistic. Navigation never waits for a network-backed future
before showing the selected destination. A preparation that finishes after
activation cannot move the entry lifecycle backwards from `active`.

# Feature preparation policy

Preparation is intentionally restricted to local work:

- **Schedule:** constructs the shared weekly view model and reads the visible
  week from the local schedule cache. The existing delayed refresh remains owned
  by the view model.
- **Canteen:** loads the selected location and current-week local cache with
  network refresh disabled. The visible page retains its existing refresh and
  adjacent-prefetch behavior.
- **Dates:** reads source and selection preferences only. Date cache/remote
  updates begin from the page's existing delayed initialization after activation.
- **Dualis:** session restoration remains tied to actual page visibility and is
  not proactively started by the navigation coordinator.

Merely opening the drawer does not prepare every cold section. Selecting a cold
section starts only that section's preparation on close, then activates it after
the preserved drawer-close delay and an interaction-free frame even if its
preparation future is still running.

# Startup orchestration

The root background, foreground-heavy, app-launch-dialog, and Canteen prewarm
jobs retain their existing minimum delays. Their deadlines are now minimums:
active pointer, scroll, drawer, or route interactions postpone execution.

The former independent Schedule cache warmup was removed because Schedule
preparation now owns that cache read. The Canteen startup prewarm reuses the same
navigation-entry preparation future instead of creating a second initialization
path.

# Regression coverage

Tests verify that:

- task IDs deduplicate and tasks remain strictly serialized;
- one clean frame separates queued tasks;
- pointer/scroll/drawer/route leases postpone work;
- a repeating loading animation cannot starve the queue;
- cancelled tasks and idle waiters complete safely on disposal;
- a cold section is not mounted during drawer close;
- merely opening the drawer does not start every section preparation;
- a destination mounts without waiting for a blocked preparation future;
- scroll interaction leases release after scrolling settles;
- entry preparation runs once and cannot overwrite the `active` lifecycle;
- Canteen preparation reads cache without a network refresh;
- Dates preparation reads preferences without a remote request;
- the initial Schedule placeholder and delayed mount contract remain intact.

# Validation

- full `flutter analyze` — clean;
- `flutter test test/canteen` — 59 tests passed;
- `flutter test test/date_management` — 29 tests passed;
- `flutter test test/schedule` — 155 tests passed;
- `flutter test test/ui` — 38 tests passed;
- focused coordinator/navigation lifecycle and cache-only preparation tests passed;
- Pixel 8 Pro profile mode at 120 Hz / 1.0x animations, using three current-`v2`
  control runs and three final branch runs.

Median Pixel results:

| Scenario | Metric | Current `v2` | Final branch |
| --- | --- | ---: | ---: |
| Drawer → Canteen | frames > 8.33 ms | 25.00% | 13.33% |
| Drawer → Canteen | p95 | 25.48 ms | 10.21 ms |
| Drawer → Canteen | frames > 16.67 ms | 3 | 1 |
| Drawer → Canteen | consecutive misses | 3 | 1 |
| Drawer → Dates | p95 | 18.96 ms | 13.46 ms |
| Drawer → Dates | p99 / worst | 36.67 ms | 26.83 ms |
| Drawer → Dates | frames > 33 ms | 1 | 0 |
| Drawer → Dualis | frames > 8.33 ms | 23.53% | 10.81% |
| Drawer → Dualis | p95 | 18.79 ms | 14.19 ms |
| Drawer → Dualis | p99 / worst | 36.82 ms | 19.89 ms |
| Drawer → Dualis | frames > 33 ms | 1 | 0 |

The remaining Dates loading-progression warning is the known baseline issue fixed
by the separate Dates lazy-rendering PR. All navigation final states completed.

# Constraints preserved

- no animation was removed or shortened;
- the drawer still closes before destination activation;
- no performance-harness thresholds or fixture data were changed;
- no production data source is replaced with fixture behavior;
- network refresh remains available after the relevant page is active.

# Stacking

This change is based on the approved Canteen rendering branch so the navigation
preparation hook extends the stable Canteen shell instead of replacing its
initialization lifecycle. Merge PR #97 before this branch, then retarget this PR
to `v2`.
