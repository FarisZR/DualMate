import 'dart:async';
import 'dart:developer' as developer;

import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';

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
      unawaited(
        AppDiagnostics.instance.recordInfo(
          'perf.frame',
          'janky frame timing',
          data: {
            'buildMs': build,
            'rasterMs': raster,
          },
        ),
      );
    }
  }

  /// Mark a navigation-related event in the timeline and log it.
  void markNavEvent({required String name}) {
    developer.Timeline.startSync('nav:$name');
    developer.Timeline.finishSync();
    developer.log('nav event: $name', name: 'perf.nav');
    unawaited(
      AppDiagnostics.instance.recordNavigation(name, data: {'source': 'app'}),
    );
  }

  /// Mark a timestamped span; caller is responsible for balancing start/finish.
  PerformanceTelemetryTask startTask(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
  }) {
    final timelineTask = developer.TimelineTask(filterKey: 'perf');
    timelineTask.start(name);
    final diagnosticsSpan = AppDiagnostics.instance.startSpan(
      name,
      description: name,
      data: args,
    );
    return PerformanceTelemetryTask._(timelineTask, diagnosticsSpan);
  }

  /// Convenience to log a single instant with an optional payload.
  void logInstant(String name, {Map<String, Object?>? args}) {
    developer.log(name, name: 'perf.instant', error: args);
    unawaited(
      AppDiagnostics.instance.recordInfo('perf.instant', name, data: args ?? {}),
    );
  }
}

class PerformanceTelemetryTask {
  final developer.TimelineTask _timelineTask;
  final AppDiagnosticsSpan _diagnosticsSpan;
  bool _finished = false;

  PerformanceTelemetryTask._(this._timelineTask, this._diagnosticsSpan);

  void setData(String key, Object? value) {
    _diagnosticsSpan.setData(key, value);
  }

  void setTag(String key, String value) {
    _diagnosticsSpan.setTag(key, value);
  }

  Future<void> finish({SpanStatus status = const SpanStatus.ok()}) async {
    if (_finished) return;
    _finished = true;
    _timelineTask.finish();
    await _diagnosticsSpan.finish(status: status);
  }

  Future<void> fail(Object error,
      {SpanStatus status = const SpanStatus.internalError()}) async {
    if (_finished) return;
    _finished = true;
    _diagnosticsSpan.attachError(error);
    _timelineTask.finish();
    await _diagnosticsSpan.finish(status: status);
  }

  bool get isFinished => _finished;
}
