import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
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
  static const Set<String> _allowedStatusValues = <String>{
    'success',
    'empty',
    'network_error',
    'parse_error',
    'cancelled',
    'skipped',
  };

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
          data: {'buildMs': build, 'rasterMs': raster},
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
    final data = <String, Object?>{..._coarseDeviceContext(), ...args};
    final diagnosticsSpan = AppDiagnostics.instance.startSpan(
      name,
      description: name,
      data: data,
    );
    return PerformanceTelemetryTask._(timelineTask, diagnosticsSpan);
  }

  Future<T> measureTask<T>(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
    String successStatus = 'success',
    String Function(T result)? successStatusForResult,
    required FutureOr<T> Function(PerformanceTelemetryTask task) action,
  }) async {
    final startedAt = DateTime.now();
    final task = startTask(name, args: args);
    try {
      final result = await action(task);
      if (!task.isFinished) {
        task.setCoarseStatus(
          _resolveSuccessStatus(result, successStatus, successStatusForResult),
        );
        task.setDurationSince(startedAt);
        await task.finish();
      }
      return result;
    } on OperationCancelledException catch (error) {
      task.setCoarseStatus('cancelled');
      task.setDurationSince(startedAt);
      await task.fail(error, includeErrorMessage: false);
      rethrow;
    } catch (error) {
      task.setCoarseStatus(statusForError(error));
      task.setDurationSince(startedAt);
      await task.fail(error, includeErrorMessage: false);
      rethrow;
    } finally {
      if (!task.isFinished) {
        task.setDurationSince(startedAt);
        await task.finish();
      }
    }
  }

  T measureSync<T>(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
    String successStatus = 'success',
    required T Function(PerformanceTelemetryTask task) action,
  }) {
    final startedAt = DateTime.now();
    final task = startTask(name, args: args);
    try {
      final result = action(task);
      if (!task.isFinished) {
        task.setCoarseStatus(successStatus);
        task.setDurationSince(startedAt);
        unawaited(task.finish());
      }
      return result;
    } catch (error) {
      task.setCoarseStatus(statusForError(error));
      task.setDurationSince(startedAt);
      unawaited(task.fail(error, includeErrorMessage: false));
      rethrow;
    } finally {
      if (!task.isFinished) {
        task.setDurationSince(startedAt);
        unawaited(task.finish());
      }
    }
  }

  /// Convenience to log a single instant with an optional payload.
  void logInstant(String name, {Map<String, Object?>? args}) {
    developer.log(name, name: 'perf.instant', error: args);
    unawaited(
      AppDiagnostics.instance.recordInfo(
        'perf.instant',
        name,
        data: args ?? {},
      ),
    );
  }

  Map<String, Object?> _coarseDeviceContext() {
    final refreshRateHz = _refreshRateHz();
    return <String, Object?>{
      if (refreshRateHz != null) 'deviceTier': _deviceTier(refreshRateHz),
    };
  }

  int? _refreshRateHz() {
    try {
      final views = PlatformDispatcher.instance.views;
      if (views.isEmpty) return null;
      final refreshRate = views.first.display.refreshRate;
      if (refreshRate <= 0) return null;
      return refreshRate.round();
    } catch (_) {
      return null;
    }
  }

  String _deviceTier(int refreshRateHz) {
    if (refreshRateHz >= 120) return 'high_refresh';
    if (refreshRateHz >= 90) return 'mid_refresh';
    return 'standard_refresh';
  }

  @visibleForTesting
  static String statusForError(Object error) {
    final type = error.runtimeType.toString().toLowerCase();
    if (type.contains('cancel')) return 'cancelled';
    if (error is FormatException ||
        type.contains('parse') ||
        type.contains('parser') ||
        type.contains('format')) {
      return 'parse_error';
    }
    if (type.contains('request') ||
        type.contains('socket') ||
        type.contains('http') ||
        type.contains('network')) {
      return 'network_error';
    }
    return 'network_error';
  }

  static bool isAllowedStatus(String value) =>
      _allowedStatusValues.contains(value);

  static String _resolveSuccessStatus<T>(
    T result,
    String successStatus,
    String Function(T result)? successStatusForResult,
  ) {
    if (successStatusForResult == null) return successStatus;
    try {
      return successStatusForResult(result);
    } catch (_) {
      return successStatus;
    }
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

  void setCoarseStatus(String status) {
    if (PerformanceTelemetry.isAllowedStatus(status)) {
      setData('status', status);
    }
  }

  void setDurationSince(DateTime startedAt) {
    setData('durationMs', DateTime.now().difference(startedAt).inMilliseconds);
  }

  Future<void> finish({SpanStatus status = const SpanStatus.ok()}) async {
    if (_finished) return;
    _finished = true;
    _timelineTask.finish();
    await _diagnosticsSpan.finish(status: status);
  }

  Future<void> fail(
    Object error, {
    SpanStatus status = const SpanStatus.internalError(),
    bool includeErrorMessage = true,
  }) async {
    if (_finished) return;
    _finished = true;
    _diagnosticsSpan.attachError(
      error,
      includeErrorMessage: includeErrorMessage,
    );
    _timelineTask.finish();
    await _diagnosticsSpan.finish(status: status);
  }

  bool get isFinished => _finished;
}
