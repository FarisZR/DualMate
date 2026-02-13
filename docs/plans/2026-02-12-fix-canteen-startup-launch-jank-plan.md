---
title: fix: canteen startup launch jank with deferred refresh orchestration
type: fix
date: 2026-02-12
---

# fix: canteen startup launch jank with deferred refresh orchestration

## Overview
Startup interaction still felt janky on Android when users navigated quickly to canteen right after launch. Schedule optimizations were already effective, but canteen still had launch-window load pressure.

This plan reduces launch-time contention by separating startup heavy work, making canteen refresh stale-gated, and replacing eager multi-week canteen loading with cache-first visible-week loading plus debounced adjacent cache prefetch.

## Problem Statement / Motivation
- Foreground startup still triggered canteen refresh work close to first interactions.
- Canteen entry loaded context weeks eagerly (current, next, previous), increasing startup-window isolate/network/DB pressure.
- Repeated same-week refreshes had no in-flight dedupe.
- Integration smoke flow was brittle due to startup dialogs and host-loopback assumptions.

## Proposed Solution
1. Split startup heavy init:
- Keep startup heavy path calendar-only.
- Move canteen prewarm into a separate one-time function scheduled later at idle priority.

2. Add stale-gated + deduplicated canteen refresh:
- Introduce provider `refreshWeekIfStale(...)` with in-memory stale tracking and per-week in-flight dedupe.

3. Rework canteen page/viewmodel load orchestration:
- Prime only the currently visible week on entry.
- Refresh visible week stale-gated on day/page changes.
- Debounce adjacent week cache prefetch and disable network refresh for that prefetch path.

4. Harden integration coverage:
- Add startup->canteen responsiveness integration test.
- Update existing performance smoke test to dismiss blocking dialogs and avoid localhost-only schedule assumptions.

## Acceptance Criteria
- [x] Startup heavy init no longer performs canteen refresh directly.
- [x] Canteen page no longer loads 3 weeks eagerly on first frame.
- [x] Same-week concurrent refresh requests are deduplicated.
- [x] Canteen launch-window interaction integration test passes on connected Android device.
- [x] Existing canteen bounds and visible-day tests remain green.

## Test Plan
- Unit/widget:
  - `test/common/appstart/app_initializer_startup_policy_test.dart`
  - `test/canteen/business/canteen_provider_refresh_policy_test.dart`
  - `test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart`
  - `test/canteen/ui/viewmodels/canteen_visible_days_test.dart`
  - `test/canteen/ui/canteen_page_bounds_test.dart`
- Integration (Android device):
  - `integration_test/canteen_startup_responsiveness_test.dart`
  - `integration_test/performance_smoke_test.dart`

## Risks / Mitigations
- Risk: canteen freshness may lag if startup prewarm is too deferred.
  - Mitigation: stale-gated visible-week refresh still runs on canteen entry and page change.
- Risk: delayed prefetch may reduce immediate adjacent-week readiness.
  - Mitigation: keep debounced adjacent cache prefetch enabled.
