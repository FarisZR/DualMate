---
module: Schedule
date: 2026-10-24
problem_type: ui_bug
component: timetable_customization
root_cause: offscreen_loading_feedback
resolution_type: ui_state
severity: medium
tags: [schedule, loading, material3, expressive, accessibility]
---

# Visible feedback while adding a timetable

Adding or changing a source waits for its lesson preview before inserting the
configured timetable. The previous loading bar lived in the scrollable body
header, above the Add timetable action. It was often off screen while the body
was ignoring input, making even a short network request feel unresponsive.

The pending operation now retains its timetable identity and displays a pinned
status above Save: a contained, morphing shape indicator, a localized loading
message, and the class name. It appears on the first frame during the request
and clears in the existing `finally` path on success or failure. There is no
minimum display time or added network delay. The existing error message and
uncommitted source behavior are preserved.

The status is a screen-reader live region. Reduced motion displays a static
shape. Only the small indicator rebuilds on animation ticks, behind its own
repaint boundary; the module list remains lazy.

The title belongs to the app bar, with the first class immediately below it.
The primary group is named “Main course” / “Hauptkurs”.
The app bar uses the scaffold background with transparent surface tint and zero
scrolled-under elevation so scrolling cannot introduce another background color.

## Material implementation

The [Material loading indicator guidance](https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md)
recommends morphing shapes for short indeterminate waits. Flutter's dedicated
component is [still tracked upstream](https://github.com/flutter/flutter/issues/184941).
This implementation uses the official `material_ui` 1.8.0 `MaterialShapes` and
[`MaterialShapeBorder` interpolation](https://pub.dev/documentation/material_ui/latest/material_ui/MaterialShapeBorder-class.html),
with the standard seven-shape sequence and the application's existing Flutter
theme. Importing only the shape APIs avoids mixing the two separate theme trees.
The package was already a transitive dependency; declaring it directly adds no
new resolved packages.

## Regression coverage

Widget tests hold a source request open until explicitly completed, verifying
visible pinned feedback, its source name and accessibility announcement,
disabled Save, successful insertion, and failure cleanup. Layout tests cover
English/German, light/dark, 320/393/800 dp widths, and 1.8× text at 320 dp.
Indicator tests exercise morphing across the full sequence, reduced motion,
resuming animation, and disposal.

The device integration test gates its loopback iCal response while capturing
the pending state, then releases it and verifies selection, Save, and offline
reopening. This gate exists only in the test. Visual capture uses the isolated
fixture application and remains separate from the continuous cold stress run.

Validation: the schedule suite plus indicator tests passed (299 tests). After
the final wording change, all 26 customization/indicator tests passed again.
The Pixel and Huawei MRDI_W09 tablet integration flows passed in both themes,
including German. Tablet captures use landscape in the isolated fixture app,
with the device's existing resolution and density settings preserved. The full
cold stress run is omitted at the user's explicit request; these changes make
no new performance measurement claims.
