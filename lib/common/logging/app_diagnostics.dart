import 'dart:async';

import 'package:sentry/sentry.dart';

abstract class DiagnosticsRecorder {
  Future<void> addBreadcrumb(Breadcrumb breadcrumb);

  Future<void> captureException(
    Object exception,
    StackTrace stackTrace, {
    SentryMessage? message,
    Map<String, String> tags,
    Map<String, Object?> contexts,
  });

  ISentrySpan? getCurrentSpan();

  ISentrySpan startTransaction(String operation, {String? description});
}

class SentryDiagnosticsRecorder implements DiagnosticsRecorder {
  const SentryDiagnosticsRecorder();

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) {
    return Sentry.addBreadcrumb(breadcrumb);
  }

  @override
  Future<void> captureException(
    Object exception,
    StackTrace stackTrace, {
    SentryMessage? message,
    Map<String, String> tags = const <String, String>{},
    Map<String, Object?> contexts = const <String, Object?>{},
  }) {
    return Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      message: message,
      withScope: (scope) {
        for (final entry in tags.entries) {
          scope.setTag(entry.key, entry.value);
        }
        for (final entry in contexts.entries) {
          scope.setContexts(entry.key, entry.value);
        }
      },
    );
  }

  @override
  ISentrySpan? getCurrentSpan() => Sentry.getSpan();

  @override
  ISentrySpan startTransaction(String operation, {String? description}) {
    return Sentry.startTransaction(
      operation,
      'task',
      description: description,
      bindToScope: true,
    );
  }
}

class AppDiagnostics {
  final DiagnosticsRecorder _recorder;

  AppDiagnostics({DiagnosticsRecorder? recorder})
      : _recorder = recorder ?? const SentryDiagnosticsRecorder();

  static final AppDiagnostics instance = AppDiagnostics();

  Future<void> recordNavigation(
    String name, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return _bestEffort(
      () => _recorder.addBreadcrumb(
        Breadcrumb(
          category: 'navigation',
          type: 'navigation',
          message: name,
          data: data,
          level: SentryLevel.info,
        ),
      ),
    );
  }

  Future<void> recordInfo(
    String category,
    String message, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return _bestEffort(
      () => _recorder.addBreadcrumb(
        Breadcrumb(
          category: category,
          type: 'default',
          message: message,
          data: data,
          level: SentryLevel.info,
        ),
      ),
    );
  }

  Future<void> reportCaughtException(
    Object exception,
    StackTrace stackTrace, {
    String? message,
    Map<String, String> tags = const <String, String>{},
    Map<String, Object?> contexts = const <String, Object?>{},
  }) {
    return _bestEffort(
      () => _recorder.captureException(
        exception,
        stackTrace,
        message: message == null ? null : SentryMessage(message),
        tags: tags,
        contexts: contexts,
      ),
    );
  }

  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Diagnostics must never break app flows.
    }
  }

  AppDiagnosticsSpan startSpan(
    String operation, {
    String? description,
    Map<String, Object?> data = const <String, Object?>{},
    Map<String, String> tags = const <String, String>{},
  }) {
    final parent = _recorder.getCurrentSpan();
    final span = parent?.startChild(
          operation,
          description: description,
        ) ??
        _recorder.startTransaction(operation, description: description);

    for (final entry in data.entries) {
      span.setData(entry.key, entry.value);
    }
    for (final entry in tags.entries) {
      span.setTag(entry.key, entry.value);
    }

    return AppDiagnosticsSpan._(span);
  }
}

class AppDiagnosticsSpan {
  final ISentrySpan _span;

  AppDiagnosticsSpan._(this._span);

  void setData(String key, Object? value) {
    _span.setData(key, value);
  }

  void setTag(String key, String value) {
    _span.setTag(key, value);
  }

  void attachError(Object error) {
    _span.throwable = error;
  }

  Future<void> finish({SpanStatus? status}) {
    return _span.finish(status: status);
  }
}
