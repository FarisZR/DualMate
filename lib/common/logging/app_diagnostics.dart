import 'dart:async';
import 'dart:developer' as developer;

import 'package:sentry/sentry.dart';

import 'sentry_scrubber.dart';

void _logDiagnosticsFailure(
  String operation,
  Object error, [
  StackTrace? stackTrace,
]) {
  developer.log(
    'Diagnostics $operation failed',
    name: 'diagnostics',
    error: error,
    stackTrace: stackTrace,
  );
}

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
      description ?? operation,
      operation,
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
          message: sanitizeDiagnosticsName(name),
          data: sanitizeDiagnosticsMap(data),
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
          category: sanitizeDiagnosticsName(category),
          type: 'default',
          message: sanitizeDiagnosticsName(message),
          data: sanitizeDiagnosticsMap(data),
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
        message: message == null
            ? null
            : SentryMessage(sanitizeDiagnosticsName(message)),
        tags: sanitizeDiagnosticsTags(tags),
        contexts: sanitizeDiagnosticsMap(contexts),
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
    try {
      final parent = _recorder.getCurrentSpan();
      final sanitizedOperation = sanitizeDiagnosticsName(operation);
      final sanitizedDescription = description == null
          ? null
          : sanitizeDiagnosticsName(description);
      final span =
          parent?.startChild(
            sanitizedOperation,
            description: sanitizedDescription,
          ) ??
          _recorder.startTransaction(
            sanitizedOperation,
            description: sanitizedDescription,
          );

      final diagnosticsSpan = AppDiagnosticsSpan._(span);
      for (final entry in data.entries) {
        diagnosticsSpan.setData(entry.key, entry.value);
      }
      for (final entry in tags.entries) {
        diagnosticsSpan.setTag(entry.key, entry.value);
      }

      return diagnosticsSpan;
    } catch (error, stackTrace) {
      _logDiagnosticsFailure('startSpan', error, stackTrace);
      return const AppDiagnosticsSpan.noop();
    }
  }
}

class AppDiagnosticsSpan {
  final ISentrySpan? _span;

  const AppDiagnosticsSpan._(this._span);

  const AppDiagnosticsSpan.noop() : _span = null;

  void setData(String key, Object? value) {
    final span = _span;
    if (span == null) return;
    try {
      final sanitized = sanitizeDiagnosticsValue(value, key: key);
      if (sanitized != null && sanitized != sentryRedactedValue) {
        span.setData(key, sanitized);
      }
    } catch (error, stackTrace) {
      _logDiagnosticsFailure('span.setData', error, stackTrace);
    }
  }

  void setTag(String key, String value) {
    final span = _span;
    if (span == null) return;
    try {
      span.setTag(key, sanitizeDiagnosticsValue(value, key: key).toString());
    } catch (error, stackTrace) {
      _logDiagnosticsFailure('span.setTag', error, stackTrace);
    }
  }

  void attachError(Object error, {bool includeErrorMessage = true}) {
    final span = _span;
    if (span == null) return;
    try {
      span.setData('errorType', error.runtimeType.toString());
      if (includeErrorMessage) {
        span.setData(
          'errorMessage',
          sanitizeDiagnosticsValue(error.toString()).toString(),
        );
      }
      span.status = const SpanStatus.internalError();
    } catch (attachErrorError, stackTrace) {
      _logDiagnosticsFailure('span.attachError', attachErrorError, stackTrace);
    }
  }

  Future<void> finish({SpanStatus? status}) async {
    final span = _span;
    if (span == null) return;
    try {
      await span.finish(status: status);
    } catch (error, stackTrace) {
      _logDiagnosticsFailure('span.finish', error, stackTrace);
    }
  }
}
