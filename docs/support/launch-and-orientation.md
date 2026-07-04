# Launch and orientation behavior

## Summary
The app no longer uses a custom splash screen. Orientation is adaptive: phones are locked to portrait, while tablets and large-screen devices keep normal system portrait/landscape behavior. A lightweight loading shell appears while initialization completes.

## What to expect on launch
- Android shows the system splash (app icon) on Android 12+.
- The first Flutter frame renders as soon as possible.
- A loading spinner is shown until the app finishes initialization.

## Orientation support
- Phone-sized displays are portrait-only because landscape leaves too little usable app space.
- Tablet and large-screen displays support normal portrait and landscape behavior.
- The app bases the orientation policy on the real Flutter display size, not the possibly letterboxed `MediaQuery` size.
- Tablet layout uses the navigation drawer alongside content.
- Phone layout uses the standard app bar and drawer.

## Troubleshooting
- If the app shows a blank screen longer than expected, check startup logs for blocking work during initialization.
- If landscape looks broken on a screen, file a bug with the screen name, orientation, and device model.

## Notes for QA
- Test cold start in portrait and landscape.
- On phones, rotate to landscape and confirm the app returns to portrait.
- On tablets or large-screen/windowed devices, confirm landscape remains available.
- Resize foldable/tablet windows across the 600dp shortest-side breakpoint and confirm the policy updates without restarting the app.

## Performance profiling quickstart
- Run profile on a device: `flutter run --profile -d <DEVICE_ID>`
- Enable perf overlay: Settings -> Developer options -> Show performance overlay
- Logs: filter `perf.` for frame timing and navigation events
- Key markers: `startup.deferFirstFrame`, `startup.allowFirstFrame`, `schedule.refresh.*`
