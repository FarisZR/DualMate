---
title: Reduce first-open jank on Dates page from drawer
date: 2026-02-28
---

# Summary

The Dates page was still causing dropped frames when opened from the drawer
right after cold startup. We reduced first-open work on the critical UI frame by
deferring initialization slightly and batching Rapla cached-window notifications.

# Findings

1. `DateManagementPage` started `viewModel.initialize` immediately after the
   first frame via idle task, which could still overlap with drawer transition
   work on slower devices.
2. Applying cached Rapla windows emitted repeated change notifications while
   paging through cached ranges, causing extra rebuild pressure during first
   render.

# Changes

- `lib/date_management/ui/date_management_page.dart`
  - deferred Dates initialization by `320ms` after first frame before scheduling
    the idle-priority initialize task.
  - added timer cleanup in `dispose`.
- `lib/date_management/ui/viewmodels/date_management_view_model.dart`
  - added optional `notify` control to important-event mutation helpers.
  - cached-window replay now loads with `notify: false` and sends a single
    consolidated section/events notify after the replay loop.
- `test/date_management/ui/date_management_page_test.dart`
  - added widget test verifying initialization is deferred and not triggered in
    the first `200ms`.

# Validation

- `flutter test test/date_management/ui/date_management_page_test.dart`
- `flutter test test/date_management/business/important_event_organizer_test.dart`
- `flutter analyze lib/date_management/ui/date_management_page.dart lib/date_management/ui/viewmodels/date_management_view_model.dart test/date_management/ui/date_management_page_test.dart`
