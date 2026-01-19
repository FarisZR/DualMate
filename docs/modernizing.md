# Modernizing Summary

## Scope
This document summarizes the design decisions, issues fixed, and the reasoning process that led to a stable, running app.

## Design Decisions
- **Provider scoping moved to feature pages**: Providers for schedule sub-pages are now created in `SchedulePage` and passed via builders. This keeps view-model ownership close to the feature, avoids cross-route scoping bugs, and makes lifetimes explicit.
- **Simplified `PagerWidget`**: Removed the generic provider wrapper from `PagerWidget`. It now only switches pages. This avoids hidden provider boundaries that can break lookups for nested widgets.
- **Safe default initialization**: `DateManagementViewModel` now initializes `_currentSelectedYear` and `_currentDateDatabase` before async preference loading to prevent late-init crashes.
- **Mounted checks around async `setState()`**: The Dualis login form now guards `setState()` after async work to avoid lifecycle race conditions.
- **Theme adjustments**: Built themes from `ThemeData.light()` and `ThemeData.dark()` with a consistent dark palette, explicit scaffold/app bar colors, and updated input decoration styles (hint/label/focus). This ensures readable hint text and a proper dark theme baseline.

## Issues Fixed and How
### 1) Navigator observer assertion crash
**Symptom**: `observer.navigator == null` assertion when navigating.
**Cause**: Observer attached to a nested navigator.
**Fix**: Removed observer usage on the nested navigator in `MainPage`.
**Why**: Observers are expected on the root navigator; nested use triggered internal assertion.

### 2) Schedule page ProviderNotFoundException
**Symptom**: `Provider<WeeklyScheduleViewModel>` not found above `WeeklySchedulePage`.
**Cause**: Provider was set in a wrapper (`PagerWidget`) that did not scope into the page’s context reliably.
**Fix**: Provide `WeeklyScheduleViewModel` and `DailyScheduleViewModel` directly in `SchedulePage` builders with `ChangeNotifierProvider.value`.
**Why**: Guarantees the provider is a parent of each schedule page widget.

### 3) Weekly schedule late initialization crash
**Symptom**: `LateInitializationError` on `currentDateStart`.
**Cause**: Access before initialization during schedule refresh.
**Fix**: Added a guard in `WeeklyScheduleViewModel` to prevent access until the date range is initialized.
**Why**: Avoids premature use of late variables during async load.

### 4) Schedule DB update null id crash
**Symptom**: `type 'Null' is not a subtype of type 'int'` in update.
**Cause**: Update attempted with a null `id` in row map.
**Fix**: Ensure the row is built after `entry.id` is set in `ScheduleEntryRepository`.
**Why**: Keeps update operations valid and consistent.

### 5) Date management late-init + dropdown assertion
**Symptom**: Late init errors for `_currentDateDatabase`/`_currentSelectedYear` and dropdown assertion about invalid value.
**Cause**: Defaults loaded asynchronously; UI accessed values before initialization.
**Fix**: Initialize safe defaults synchronously; validate preference year before applying.
**Why**: Prevents null/invalid dropdown values and avoids late-init exceptions.

### 6) Dualis login setState after dispose
**Symptom**: `setState()` called after dispose during login flow.
**Cause**: Async callbacks after widget disposal.
**Fix**: Added `mounted` checks before calling `setState()` in async flows.
**Why**: Standard Flutter lifecycle safety to prevent memory-leak-like state updates.

### 7) Theme and input text readability
**Symptom**: Missing dark theme feel; hint text looked like input text.
**Cause**: Theme was not derived from dark base; input decoration colors were not explicitly controlled.
**Fix**: Build theme from light/dark base, set dark surfaces, and explicitly set `hintStyle`, `labelStyle`, and focused/disabled border styles.
**Why**: Ensures consistent dark theme and improved contrast.

## How We Got to a Running App
1. **Observed crashes** by running the app on a device and monitoring logs.
2. **Triaged root causes** (navigator observer misuse, provider scope, late-init fields, DB updates).
3. **Applied minimal, targeted fixes** to restore correct widget lifecycles and state initialization.
4. **Re-ran the app** to validate schedule page stability and date management rendering.
5. **Hardened async UI flows** and continued to refine theme styling.

## Notes for Engineers
- The app now runs without the schedule or date management crashes that previously blocked navigation.
- The dark theme groundwork and input decoration adjustments are in place; further fine-tuning can be done in `lib/common/ui/colors.dart` if desired.
- If a device disconnects, simply re-run to validate; the core fixes do not depend on a persistent device session.
