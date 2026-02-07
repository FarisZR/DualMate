# Launch and orientation behavior

## Summary
The app no longer uses a custom splash screen. Orientation is allowed in all directions on phones and tablets. A lightweight loading shell appears while initialization completes.

## What to expect on launch
- Android shows the system splash (app icon) on Android 12+.
- The first Flutter frame renders as soon as possible.
- A loading spinner is shown until the app finishes initialization.

## Orientation support
- Portrait and landscape are supported on phones and tablets.
- Tablet layout uses the navigation drawer alongside content.
- Phone layout uses the standard app bar and drawer.

## Troubleshooting
- If the app shows a blank screen longer than expected, check startup logs for blocking work during initialization.
- If landscape looks broken on a screen, file a bug with the screen name, orientation, and device model.

## Notes for QA
- Test cold start in portrait and landscape.
- Rotate during launch and confirm the first visible screen matches the device orientation.
- Verify the main screens are usable in landscape (schedule, dualis, date management, settings, onboarding).

## Performance profiling quickstart
- Run profile on a device: `flutter run --profile -d <DEVICE_ID>`
- Enable perf overlay: Settings -> Developer options -> Show performance overlay
- Logs: filter `perf.` for frame timing and navigation events
- Key markers: `startup.deferFirstFrame`, `startup.allowFirstFrame`, `schedule.refresh.*`
