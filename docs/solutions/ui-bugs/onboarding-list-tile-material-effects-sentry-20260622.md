---
module: Onboarding UI
date: 2026-06-22
problem_type: ui_bug
component: onboarding
symptoms:
  - "Sentry reported FlutterError: ListTile background color or ink splashes may be invisible"
  - "The onboarding route emitted framework-only ListTile assertions under the animated page transition"
root_cause: onboarding_list_tiles_rendered_below_a_colored_transition_without_a_local_material_ancestor
resolution_type: code_fix
severity: low
tags: [onboarding, sentry, flutter, listtile, material]
---

# Troubleshooting: Onboarding ListTile material effects

## Problem
Sentry issue `DUALMATE-A` reported Flutter's debug check for `ListTile`
material effects during the `onboarding` transaction. The stack did not include
application frames, but the framework message identified an opaque `ColoredBox`
between `ListTile` and the nearest `Material` ancestor.

## Root Cause
The onboarding pages are rendered inside an animated transition that can insert
a colored wrapper above the active page. `RadioListTile` and `ListTile` paint
their tile background and ink effects on the nearest `Material`, so that wrapper
can hide those effects unless each tile has its own local material surface.

## Solution
- Wrapped onboarding schedule source `RadioListTile` entries in transparent
  `Material`.
- Wrapped onboarding canteen location `RadioListTile` entries in transparent
  `Material`.
- Wrapped Mannheim course `ListTile` entries in transparent `Material`.
- Added a widget regression that pumps onboarding radio pages below a
  `ColoredBox` and asserts no Flutter framework exception is emitted.

## Test Coverage
- `schedule source radios keep visible material effects under color`
- `canteen location radios keep visible material effects under color`
- `Mannheim course tiles keep visible material effects under color`

## Commands run
```bash
sentry issue view 129632365 --json --fields shortId,title,culprit,metadata,tags,firstSeen,lastSeen,count,userCount,permalink
flutter test test/ui/onboarding/onboarding_list_tile_material_test.dart
flutter test test/ui/onboarding/onboarding_list_tile_material_test.dart test/ui/onboarding/onboarding_required_canteen_step_test.dart
flutter analyze lib/ui/onboarding/widgets/select_source_page.dart lib/ui/onboarding/widgets/select_canteen_location_page.dart lib/ui/onboarding/widgets/mannheim_page.dart test/ui/onboarding/onboarding_list_tile_material_test.dart test/ui/onboarding/onboarding_required_canteen_step_test.dart
```
