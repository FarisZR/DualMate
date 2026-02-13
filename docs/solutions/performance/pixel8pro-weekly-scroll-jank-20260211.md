# Solution: Reduce Weekly Scroll Jank on High-Refresh Phones

## Symptom
- Weekly schedule scrolling felt noticeably choppier on Pixel 8 Pro than on lower-refresh devices.

## Findings
1. `WeeklySchedulePage` triggered unnecessary full-widget rebuilds when background week prefetch completed.
2. `PerformanceTelemetry` emitted frame timing logs for every frame in non-release builds, creating avoidable runtime overhead.
3. `ScheduleProvider` printed high-frequency cache/fetch logs from hot paths, increasing logging pressure during schedule interactions.

## Changes
1. Removed UI `setState` calls from prefetch completion paths in `WeeklySchedulePage`; prefetch now warms cache without forcing immediate rebuild.
2. Changed frame telemetry logging to jank-only with throttling (500ms) instead of per-frame logging.
3. Restricted verbose schedule provider logs to debug mode only (`kDebugMode`).

## Validation
- `flutter analyze` passed for touched files.
- Weekly schedule widget/viewmodel tests passed.
- Integration smoke test passed.
- Profile run on Pixel 8 Pro confirmed reduced startup log noise from schedule provider hot path.

## Notes
- This specifically targets interaction smoothness on high-refresh phones by reducing main-isolate churn during and around swipe interactions.
