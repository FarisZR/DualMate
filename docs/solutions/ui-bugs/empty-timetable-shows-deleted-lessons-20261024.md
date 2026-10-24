---
module: Schedule
date: 2026-10-24
problem_type: ui_bug
component: timetable_customization
root_cause: invalid_source_reported_as_valid_and_retained_visible_cache
resolution_type: state_invalidation
severity: medium
tags: [schedule, cache, sources, empty-state]
---

# Clear the schedule after removing the final timetable

Saving an empty timetable configuration deleted the persisted lessons, but the
weekly view kept its visible schedule and cached weeks. The final save callback
also unconditionally reported successful source setup, overriding the earlier
invalid-source notification. Reopening the schedule could consequently display
lessons from the deleted timetable instead of the setup prompt.

Source notifications now report the actual setup validity. The weekly model
invalidates its generations and caches for every source change; invalid setup
also clears the displayed schedule, queued paging result, loading/error state
and pending refresh timers. Cache reads, warmups and refreshes from a previous
generation cannot restore removed lessons. The source listener is registered
before the initial asynchronous cache read.

Once source setup finishes unsuccessfully, SchedulePage always displays its
no-source state, including after navigation preparation loads an empty cached
week. The blank grid does not draw the lesson placeholders used during loading.
Configure opens **Customize timetable**, replacing the legacy source picker.
Cached content can still appear while initial source setup is pending, and
configured offline sources retain the existing cache behavior.

## Validation

Regression tests cover final-save validity, visible and paging caches, a late
network result, startup and prefetch cache reads, completed empty setup, and the
no-source prompt/navigation in English/German and light/dark themes.

- Schedule suite: **310 passed**.
- Source setup tests with offline fixture mode enabled: **4 passed**.
- Widget capture run: **9 passed**.
- Flutter analysis and complexity lint: clean.
- Local release APK: built successfully.

This is a cache and empty-state bug fix, so the full cold performance harness is
not required.

Device validation and device video were skipped at the user's request after the
tablet disconnected. The checked-in screenshots are actual Flutter widget
renders, **not device captures**. Generate them with:

```sh
flutter test test/schedule/ui/schedule_page_test.dart \
  --dart-define=CAPTURE_TIMETABLE_EMPTY_STATE=true
```

The capture mode loads Flutter SDK's bundled Roboto font instead of the test
font. Normal test runs do not produce files.
