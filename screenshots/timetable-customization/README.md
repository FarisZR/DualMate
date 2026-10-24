# Timetable customization evidence

Captured from the actual Flutter screen on the connected Huawei MRDI_W09 tablet
(Android API 31, 2800 × 1840). These are deterministic local fixtures in the
separate `com.fariszr.dualmate.perf` application. The existing primary Rapla cache
is combined with an iCal feed served over loopback, selected in the source form,
then reopened after the server stops to verify the offline path.

- `timetable-tablet-light.png`: English, light theme.
- `timetable-tablet-dark.png`: English, dark theme.
- `timetable-tablet-dark-de.png`: German, dark theme.

Video capture is unavailable on this tablet because its Android image does not
include `screenrecord`. The screenshots are the available visual evidence.

Reproduce visual QA with the current stable Flutter SDK:

```sh
flutter drive --profile --flavor localrelease --no-dds --keep-app-running \
  --driver test_driver/timetable_customization_driver.dart \
  --target integration_test/timetable_customization_test.dart \
  --dart-define=PERF_TEST_OFFLINE_FIXTURES=true -d DEVICE_ID
```

The visual test converts the Flutter surface for screenshot capture. It is kept
separate from performance measurements because surface conversion is expensive.
After that test, launch `integration_test/timetable_restart_test.dart` in a new
process with the same driver and fixture define. It reads the existing SQLite
data without seeding it or restarting the loopback server, checking saved
selections and the combined offline cache after a real process restart.
The dedicated performance test exercises 160 cached modules without screenshots:

```sh
flutter drive --profile --flavor localrelease --no-dds --keep-app-running \
  --driver test_driver/timetable_performance_driver.dart \
  --target integration_test/timetable_customization_performance_test.dart \
  --dart-define=PERF_TEST_OFFLINE_FIXTURES=true -d DEVICE_ID
```

Use `TIMETABLE_PERF_OUTPUT` to retain each ranking report. Add
`--dart-define=TIMETABLE_TRACE=true` for a separate diagnostic timeline run.
All physical-device tests use live frame scheduling and normal platform
animation speeds. Unit tests also cover 320, 393 and 800 dp widths, both locales,
both themes, and 1.8× text at the narrowest width.
