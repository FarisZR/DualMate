---
title: fix: prevent calendar widget false empty-state fallback
type: fix
date: 2026-02-24
issue: 30
---

# fix: prevent calendar widget false empty-state fallback

## 🐛 Overview

Android schedule widgets intermittently render the legacy-looking `No upcoming events today` message even when upcoming classes exist in the next days. This plan hardens widget data consistency and fallback behavior so transient read/update failures do not masquerade as a true empty schedule.

## Problem Statement / Motivation

- Reported in `#30`: widget sometimes falls back to `No upcoming events today` despite expected multi-day list.
- This creates a trust issue: users cannot tell true no-events from transient widget/data failures.
- Current rendering path treats empty query results as definitive, while native DB reads can fail and currently collapse to empty.
- Update timing can expose a temporary empty window (`deleteScheduleEntriesBetween` before `saveSchedule`) that widgets may read.

## Consolidated Research

### Internal architecture and code paths

- Active schedule widget provider is `ScheduleNowWidget` (`android/app/src/main/AndroidManifest.xml:26`).
- Widget row rendering and empty-state fallback are in:
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/MultiDayViewsFactory.kt:45`
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/NowScheduleEntryViewsFactory.kt:105`
- Empty message text is `widget_schedule_empty_state` in `android/app/src/main/res/values/strings.xml:2`.
- Native schedule reads swallow exceptions and return empty arrays:
  - `android/app/src/main/kotlin/com/fariszr/dualmate/database/ScheduleProvider.kt:71`
  - `android/app/src/main/kotlin/com/fariszr/dualmate/database/ScheduleProvider.kt:84`
- Flutter schedule update order currently deletes then saves entries:
  - `lib/schedule/business/schedule_provider.dart:109`
  - `lib/schedule/business/schedule_provider.dart:110`
- Widget periodic interval is long (`86400000` ms), increasing stale incorrect-state impact:
  - `android/app/src/main/res/xml/schedule_now_widget_info.xml:9`

### Institutional learnings applied

- Background/refresh paths must be non-fatal and isolated from core data flow:
  - `docs/solutions/integration-issues/unhandled-background-exception-widget-logic-Schedule-20260124.md:88`
- Widget provider lifecycle hooks (resize/update) are critical for keeping rows fresh:
  - `docs/solutions/ui-bugs/widget-resize-and-canteen-duplication-20260127.md:25`
- Recent bridge hardening confirms refresh should remain provider-driven and resilient:
  - `docs/solutions/integration-issues/android-widget-background-refresh-after-schedule-change-20260224.md:19`

### Research decision

Local repo/docs context is strong for this bug class (existing widget architecture + multiple related fixes), so external research is skipped for this planning pass.

## ✨ Proposed Solution

Implement a false-empty prevention strategy with explicit distinction between:

1. **True empty schedule** (successful read, no upcoming entries).
2. **Temporary data unavailability** (read exception/race window).

High-level approach:

- Harden native widget data reads so transient failures do not map to semantic "no upcoming events".
- Make schedule persistence widget-read-safe (avoid exposing delete-then-empty intermediate state to widget readers).
- Add short self-heal refresh retry for transient failure paths so bad state does not persist until the 24h periodic update.
- Add targeted regression tests for issue `#30` scenario.

## Technical Considerations

- **Data consistency:** widget should observe either previous valid rows or a fully written new snapshot, never transient empty from update sequencing.
- **Fallback semantics:** empty copy only for verified empty results; use separate fallback for temporary read failure.
- **Refresh behavior:** preserve existing provider broadcast path (`DualmateWidgetBridgePlugin`) and add bounded retry when transient failure is detected.
- **Android-only scope:** aligns with project constraints in `AGENTS.md`.
- **No backward-compat constraints:** hard cutover project allows direct behavior correction.

## SpecFlow Gaps + Defaults

- **Gap:** What should render on DB/query exception?  
  **Default:** keep last known good rows when available; otherwise show temporary unavailable copy (not no-events copy).
- **Gap:** How quickly must widget recover from transient failure?  
  **Default:** schedule retry and recover within 5 minutes.
- **Gap:** Should stale data be preferred over false empty when offline/fetch fails?  
  **Default:** yes, stale rows are preferred with subtle stale indicator/copy.
- **Gap:** How to define true empty state?  
  **Default:** only after successful read of configured window returns no entries.

## ✅ Acceptance Criteria

- [ ] Widget shows multi-day class rows whenever upcoming classes exist in the configured window.
- [ ] `No upcoming events today` appears only when a successful read confirms no upcoming entries.
- [ ] Transient native read/query failure never renders false no-events state.
- [ ] During schedule refresh/update windows, widget does not regress to false empty state.
- [ ] Transient failure triggers self-heal refresh and UI recovers within 5 minutes without opening app UI.
- [ ] Existing widget refresh paths (manual app refresh, background update, resize) continue to work without regression.
- [ ] New regression tests cover issue `#30` and pass in CI.

## Success Metrics

- Repro steps from `#30` are no longer reproducible across repeated update/refresh cycles.
- No observed false-empty widget state in manual Android runs across lifecycle triggers (resize, reboot, background refresh).
- Test suite includes deterministic regression for transient-failure fallback behavior.

## Dependencies & Risks

- **Risk:** stronger fallback logic could hide true empty states if success/failure classification is wrong.  
  **Mitigation:** explicit success/failure signaling and tests for both paths.
- **Risk:** retry logic can create refresh storms.  
  **Mitigation:** bounded retry count with cooldown and per-widget dedupe.
- **Risk:** persistence/path changes can affect notification or schedule diff behavior indirectly.  
  **Mitigation:** keep callback ordering intact and re-run relevant schedule/background tests.

## 📋 Implementation Checklist (draft)

- [x] Define widget read outcome model (success with entries, success empty, transient failure) in `android/app/src/main/kotlin/com/fariszr/dualmate/database/ScheduleProvider.kt`.
- [x] Update empty-state rendering logic in `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/NowScheduleEntryViewsFactory.kt` and shared flow in `android/app/src/main/kotlin/com/fariszr/dualmate/widget/MultiDayViewsFactory.kt`.
- [ ] Ensure schedule persistence avoids transient empty exposure to widget reads in `lib/schedule/business/schedule_provider.dart` and/or corresponding repository transaction boundary files.
- [ ] Add bounded retry trigger in widget refresh path via `third_party/dualmate_widget_bridge/android/src/main/kotlin/com/fariszr/dualmate/widgetbridge/DualmateWidgetBridgePlugin.kt` and/or `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/ScheduleNowWidget.kt`.
- [ ] Add/update Android unit tests under `android/app/src/test/java/com/fariszr/dualmate/widget/` for false-empty fallback regression.
- [ ] Add/update Flutter tests under `test/schedule/background/` and `test/native/widget/` when refresh behavior contracts change.
- [ ] Document final fix in `docs/solutions/integration-issues/` or `docs/solutions/ui-bugs/` after implementation.

## Test Plan

### Automated

- Add regression test: transient DB/read failure does not render no-events fallback (`android/app/src/test/java/com/fariszr/dualmate/widget/NowScheduleEntryViewsFactoryTest.kt`).
- Add test: true empty successful read still renders no-events copy (`android/app/src/test/java/com/fariszr/dualmate/widget/NowScheduleEntryViewsFactoryTest.kt`).
- Add concurrency-oriented test for update/read sequencing around delete+save visibility (`test/schedule/business/schedule_provider_widget_consistency_test.dart`).
- Re-run related existing suites:
  - `android/app/src/test/java/com/fariszr/dualmate/widget/MultiDayWidgetHelperTest.kt`
  - `test/schedule/background/background_schedule_update_widget_refresh_test.dart`
  - `test/native/widget/android_widget_helper_background_error_test.dart`

### Manual Android verification

- Pin schedule widget with known upcoming classes; validate baseline list.
- Trigger background refresh and simulate transient data-read stress; verify no false empty-state fallback.
- Test offline/fetch-fail scenario; verify stale/temporary-unavailable behavior and later self-heal.
- Validate resize + reboot + re-add-widget flows preserve correct multi-day rendering.
- Confirm behavior without opening app UI after transient failure (recovery within target SLA).

## AI-Era Implementation Notes

- AI-assisted implementation should keep scope tight to issue `#30` and avoid unrelated widget redesign.
- Prioritize test-first workflow: create failing regression test before behavior changes.
- Any AI-generated fallback logic should receive explicit human review for semantic correctness (true empty vs temporary unavailable).

## References & Research

### Related issue

- `#30`

### Internal references

- `android/app/src/main/AndroidManifest.xml:26`
- `android/app/src/main/kotlin/com/fariszr/dualmate/widget/MultiDayViewsFactory.kt:45`
- `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/NowScheduleEntryViewsFactory.kt:105`
- `android/app/src/main/kotlin/com/fariszr/dualmate/database/ScheduleProvider.kt:71`
- `lib/schedule/business/schedule_provider.dart:109`
- `android/app/src/main/res/xml/schedule_now_widget_info.xml:9`
- `docs/multi-day-widgets.md:5`

### Institutional learnings

- `docs/solutions/integration-issues/unhandled-background-exception-widget-logic-Schedule-20260124.md:88`
- `docs/solutions/ui-bugs/widget-resize-and-canteen-duplication-20260127.md:25`
- `docs/solutions/integration-issues/android-widget-background-refresh-after-schedule-change-20260224.md:19`
- `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:27`
