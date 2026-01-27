---
title: fix: Improve schedule calendar swipe responsiveness
type: fix
date: 2026-01-27
---

# fix: Improve schedule calendar swipe responsiveness

## Overview
Users report that the schedule calendar block requires multiple swipes to advance to the next week, while the canteen page responds immediately. The goal is to make swipe navigation on the schedule page feel as responsive and predictable as the canteen PageView behavior, without breaking existing schedule entry interactions or vertical scrolling.

## Problem Statement / Motivation
- Swipe gestures on the schedule calendar block are inconsistent; short or partial swipes often fail and require repetition.
- The canteen page uses PageView paging and feels noticeably more responsive, creating a UX mismatch.
- The current weekly schedule uses a manual horizontal drag threshold that may be too strict or sensitive to diagonal motion.

## Proposed Solution
- Confirm the affected surface: weekly schedule swipe (week change) and reproduce on-device using `flutter run -d` (DEVICE ID THORUGH `flutter devices`)
- Align gesture recognition with the canteen PageView feel by either:
  - Tuning the existing horizontal drag handling to use screen-relative thresholds and diagonal tolerance, or
  - Replacing the weekly schedule swipe wrapper with PageView-driven paging (similar physics), keeping existing week navigation buttons.
- Ensure swipes beginning on schedule entries are still recognized as swipe when the horizontal delta exceeds the threshold.
- Preserve existing animations (SharedAxisTransition) and Material 3 visual language.

## Technical Considerations
- Gesture conflict: schedule entry taps/long-presses vs horizontal swipe recognition.
- Diagonal swipes: define axis dominance to prevent vertical scroll from being hijacked.
- Threshold scaling: prefer screen-width-relative distance plus a reasonable velocity threshold.
- Boundaries: confirm whether week navigation is infinite; if not, define feedback on boundary swipes.
- Localization: avoid new strings; if feedback UI is added, update i18n in `lib/common/i18n`.
- Platform scope: Android only (per project constraints).

## Acceptance Criteria
- A single, normal horizontal swipe on the schedule calendar block advances to the next/previous week (or day if daily view is in scope).
- Swipes that start on a schedule entry still navigate when horizontal delta exceeds the threshold; taps remain unaffected for small movement.
- Diagonal swipes register as horizontal when |dx| > |dy| * 1.2 (or equivalent tolerance).
- Vertical scrolling remains functional when vertical movement dominates.
- Swipe responsiveness feels comparable to the canteen page (no repeated swipes needed in common use).
- Existing navigation buttons (chevrons/today) continue to work.
- Add widget/gesture tests for swipe detection and direction handling.
- Manual verification on an Android device with logs captured in the debugger.
- Update schedule-related docs to note swipe behavior; update README if user-facing behavior changes are described there.

## Success Metrics
- Manual QA: 5/5 swipe attempts succeed across three gesture styles (short, medium, fast) on at least one Android phone.
- No regression in schedule entry tap/long-press behavior during swipe testing.

## Dependencies & Risks
- Risk of breaking schedule entry interaction if gesture arena priorities are changed.
- Risk of over-triggering week changes if thresholds are too low.
- PageView replacement may conflict with existing SharedAxisTransition animations.

## Open Questions
- Should swipe behavior mirror canteen PageView physics exactly, or just be “more responsive” with tuned thresholds?
Answer: it should be more responsive, the canteen page may be too responsive for a calendar block.

## References & Research 
- Weekly schedule swipe handler: `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart:89`
- Weekly schedule navigation buttons: `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart:191`
- Schedule page view switching: `lib/schedule/ui/schedule_page.dart:43`
- Daily schedule page (no swipe handling): `lib/schedule/ui/dailyschedule/daily_schedule_page.dart:27`
- Canteen PageView swipe reference: `lib/canteen/ui/canteen_page.dart:123`
- Canteen swipe behavior doc: `docs/canteen-feature.md`
- Learnings scan: no `docs/solutions` entries matched (directory empty)
- External research: skipped (strong local patterns; low-risk UI change)

## AI-Era Notes
- Local repo research via internal tooling; spec-flow analysis used to identify gesture edge cases.
