# Timetable loading feedback

Captured on the connected Pixel 8 Pro in profile mode using the isolated
`com.fariszr.dualmate.perf` fixture app and the phone's existing animation settings.
The phone's original DualMate installation and its data are untouched.

- `timetable-phone-loading-light.png`: pending iCal lessons, English/light.
- `timetable-phone-loading-dark.png`: pending iCal lessons, English/dark.
- `timetable-phone-loading-dark-de.png`: pending iCal lessons, German/dark.
- `timetable-phone-loading-light-de.png`: pending iCal lessons, German/light.
- `timetable-phone-light.png`: saved mixed timetable, English/light.
- `timetable-phone-dark.png`: saved mixed timetable, English/dark.
- `timetable-phone-dark-de.png`: saved mixed timetable, German/dark.
- `timetable-phone-light-de.png`: saved mixed timetable, German/light.
- `loading-demo.mp4`: native recording of the fixture flow.

The loopback server's response is held by a test-controlled gate for screenshots;
the app has no artificial loading delay. The test releases the response, selects
a module from the additional class, saves, stops the server, and reopens offline.

```sh
ANDROID_SERIAL=DEVICE_ID \
SCREENSHOT_OUTPUT_DIR=screenshots/timetable-loading-feedback \
RECORD_UI_VIDEO=true \
flutter drive --profile --flavor localrelease --no-dds --no-pub \
  --keep-app-running --device-id DEVICE_ID \
  --driver test_driver/timetable_customization_driver.dart \
  --target integration_test/timetable_customization_test.dart \
  --dart-define=PERF_TEST_OFFLINE_FIXTURES=true \
  --dart-define=RECORD_UI_DEMO=true
```

Video capture requires Android's `screenrecord` binary. These are visual QA
artifacts, not performance measurements. The full cold performance run was
skipped at the user's request.

## Tablet captures

`tablet/timetable-tablet-{light,dark}-de.png` show the same saved mixed timetable
in German on the Huawei MRDI_W09 (2800 × 1840, landscape, Android API 31).
`tablet/timetable-tablet-loading-{light,dark}-de.png` show pending loading
feedback. English variants are retained alongside them for the localized store
deck. The German light and dark captures also appear in the repository README.

Use the same visual QA command with the tablet's serial,
`SCREENSHOT_OUTPUT_DIR=screenshots/timetable-loading-feedback/tablet`, and
`--dart-define=SCREENSHOT_DEVICE=tablet`. That define sets landscape orientation
only in the fixture app and names the captures appropriately; teardown returns
the app to the OS orientation policy. The tablet's existing resolution and
density overrides remain unchanged. The real app's installation and data are
untouched. This tablet has no `screenrecord`, so its evidence is screenshots.
