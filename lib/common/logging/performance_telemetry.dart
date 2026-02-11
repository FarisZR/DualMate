import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight perf logger for frame timings, TTFF, and navigation spans.
class PerformanceTelemetry {
  PerformanceTelemetry._();

  static final PerformanceTelemetry instance = PerformanceTelemetry._();

  bool _frameTimingListenerAttached = false;
  DateTime? _lastJankFrameLogAt;
  static const Duration _minJankLogInterval = Duration(milliseconds: 500);

  /// Attach frame timing listener once (debug/profile). No-op if already attached.
  void ensureFrameTimingListenerAttached() {
    if (kReleaseMode || _frameTimingListenerAttached) return;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    _frameTimingListenerAttached = true;
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final build = timing.buildDuration.inMilliseconds;
      final raster = timing.rasterDuration.inMilliseconds;
      final isJanky = build > 16 || raster > 16;
      if (!isJanky) continue;

      final now = DateTime.now();
      final lastLogAt = _lastJankFrameLogAt;
      if (lastLogAt != null &&
          now.difference(lastLogAt) < _minJankLogInterval) {
        continue;
      }

      _lastJankFrameLogAt = now;
      developer.log(
        'janky frame timing: build=${build}ms raster=${raster}ms',
        name: 'perf.frame',
      );
    }
  }

  /// Mark a navigation-related event in the timeline and log it.
  void markNavEvent({required String name}) {
    developer.Timeline.startSync('nav:$name');
    developer.Timeline.finishSync();
    developer.log('nav event: $name', name: 'perf.nav');
  }

  /// Mark a timestamped span; caller is responsible for balancing start/finish.
  developer.TimelineTask startTask(String name) {
    final task = developer.TimelineTask(filterKey: 'perf');
    task.start(name);
    return task;
  }

  /// Convenience to log a single instant with an optional payload.
  void logInstant(String name, {Map<String, Object?>? args}) {
    developer.log(name, name: 'perf.instant', error: args);
  }
}
