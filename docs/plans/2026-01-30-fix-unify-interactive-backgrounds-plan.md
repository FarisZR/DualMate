---
title: fix: Unify interactive background colors
type: fix
date: 2026-01-30
---

# fix: Unify interactive background colors

## Overview
Some interactive surfaces (calendar block on the schedule page and setup wizard tiles) render with a purple-tinted dark background (#151119) instead of the standard dark surface (#121212). This plan standardizes the background so interactive states do not introduce a mismatched hue.

## Problem Statement / Motivation
- Dark theme surfaces should share a consistent base background.
- A purple hue on interactive blocks looks inconsistent and undermines Material 3 polish.
- Users notice the mismatch on the schedule calendar block and setup wizard steps.

## Proposed Solution
- Identify the widgets responsible for the schedule calendar block and setup wizard tiles.
- Trace the background and interaction overlay colors (pressed, focused, selected) for these widgets.
- Replace any hard-coded or default overlay/tint that produces #151119 with theme-derived colors that resolve to #121212 in dark theme.
- Ensure the standard background and interaction states are consistent across both surfaces.

## Technical Considerations
- Material interaction overlays can be driven by `ColorScheme` or widget `overlayColor` defaults.
- Dark theme surface defaults are defined in `lib/common/ui/colors.dart` and should remain the single source of truth.
- Avoid breaking accessibility focus visuals; if focus state needs to be distinct, use a subtle opacity on top of #121212 without color shift.
- Scope is Android only.

## Acceptance Criteria
- Schedule calendar block background matches `Theme.of(context).scaffoldBackgroundColor` in dark theme (no purple hue).
- Setup wizard interactive tiles use a subtle neutral overlay on interaction states (no purple hue).
- No purple-tinted background is visible on these elements after interaction.
- Light theme behavior is unchanged.
- Manual verification on an Android device with debugger logs.
- Add or update widget tests to verify background color resolution (where feasible).

## Success Metrics
- Visual QA: 5/5 interactions on schedule calendar block and setup wizard show consistent dark background.
- No regression in tap/press/focus behavior for either surface.

## Dependencies & Risks
- Risk: overriding overlays could reduce focus visibility for accessibility.
- Risk: other widgets may share the same style and need adjustment.

## Open Questions
- Is the scope limited to schedule calendar block and setup wizard tiles, or should this be a shared style applied to similar interactive cards?
- Is the purple hue tied to Android 12+ dynamic color? (Assumed: no explicit dynamic color support is intended here.)

## References & Research
- Theme and dark surface colors: `lib/common/ui/colors.dart:76`
- Schedule page root: `lib/schedule/ui/schedule_page.dart:1`
- Weekly schedule page: `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart:1`
- Onboarding page: `lib/ui/onboarding/onboarding_page.dart:1`
- Onboarding background: `lib/ui/onboarding/widgets/onboarding_page_background.dart:1`
- Theme selection dialog: `lib/ui/settings/select_theme_dialog.dart:1`
- Learnings scan: reviewed `docs/solutions`; no theming or color-mismatch entries found.
- External research: skipped (low-risk local UI fix; strong local theme patterns).

## AI-Era Notes
- Repo research used to locate theme entry points and onboarding/schedule components.
- Spec-flow analysis used to capture interaction states and accessibility risks.
