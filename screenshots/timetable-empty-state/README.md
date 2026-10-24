# Empty timetable state

Flutter widget renders at 393 × 852 logical pixels in English and German,
light and dark. These show the schedule body with no configured timetable;
they are not Android device captures and include no system bars or app shell.

The regression test supplies a cached lesson and an unconfigured source,
verifies the weekly view is absent, captures the empty state, and checks that
Configure opens Customize timetable. The grid contains no lesson placeholders.

```sh
flutter test test/schedule/ui/schedule_page_test.dart \
  --dart-define=CAPTURE_TIMETABLE_EMPTY_STATE=true
```

Device checks and recording were skipped at the user's request.
