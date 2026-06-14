import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:sentry/sentry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recordNavigation adds a navigation breadcrumb', () async {
    final recorder = _RecordingDiagnosticsRecorder();
    final diagnostics = AppDiagnostics(recorder: recorder);

    await diagnostics.recordNavigation(
      'drawer.tab.schedule',
      data: {'route': 'schedule'},
    );

    expect(recorder.breadcrumbs, hasLength(1));
    final breadcrumb = recorder.breadcrumbs.single;
    expect(breadcrumb.category, 'navigation');
    expect(breadcrumb.type, 'navigation');
    expect(breadcrumb.message, 'drawer.tab.schedule');
    expect(breadcrumb.data?['route'], 'schedule');
  });

  test('reportCaughtException records feature context', () async {
    final recorder = _RecordingDiagnosticsRecorder();
    final diagnostics = AppDiagnostics(recorder: recorder);
    final error = StateError('boom');
    final trace = StackTrace.current;

    await diagnostics.reportCaughtException(
      error,
      trace,
      message: 'Root init failed',
      tags: {'feature': 'startup'},
      contexts: {
        'diagnostics': {'operation': 'root.initialize'},
      },
    );

    expect(recorder.capturedExceptions, hasLength(1));
    final captured = recorder.capturedExceptions.single;
    expect(captured.exception, same(error));
    expect(captured.stackTrace, same(trace));
    expect(captured.message?.formatted, 'Root init failed');
    expect(captured.tags['feature'], 'startup');
    final diagnosticsContext = captured.contexts['diagnostics'];
    expect(diagnosticsContext, isNotNull);
    final diagnosticsMap = Map<String, dynamic>.from(
      diagnosticsContext! as Map<Object?, Object?>,
    );
    expect(diagnosticsMap['operation'], 'root.initialize');
  });

  test('diagnostics recording is best effort when recorder fails', () async {
    final recorder = _FailingDiagnosticsRecorder();
    final diagnostics = AppDiagnostics(recorder: recorder);

    await expectLater(
      diagnostics.recordNavigation('drawer.tab.schedule'),
      completes,
    );
    await expectLater(diagnostics.recordInfo('startup', 'init'), completes);
    await expectLater(
      diagnostics.reportCaughtException(StateError('boom'), StackTrace.current),
      completes,
    );
    expect(recorder.breadcrumbAttempts, 2);
    expect(recorder.captureExceptionAttempts, 1);
  });

  test('startSpan creates child span from current span', () async {
    final recorder = _RecordingDiagnosticsRecorder();
    final diagnostics = AppDiagnostics(recorder: recorder);
    final parent = _RecordingSentrySpan('parent');
    recorder.currentSpan = parent;

    final span = diagnostics.startSpan(
      'schedule.refresh',
      description: 'refresh visible week',
      data: {'origin': 'userBrowsing'},
      tags: {'feature': 'schedule'},
    );

    expect(parent.startedChildren, hasLength(1));
    final child = parent.startedChildren.single;
    expect(child.operation, 'schedule.refresh');
    expect(child.description, 'refresh visible week');
    expect(child.data.containsKey('origin'), isFalse);
    expect(child.tags['feature'], 'schedule');

    await span.finish(status: const SpanStatus.ok());
    expect(child.finished, isTrue);
    expect(child.status, const SpanStatus.ok());
  });

  test('recordInfo adds an info breadcrumb', () async {
    final recorder = _RecordingDiagnosticsRecorder();
    final diagnostics = AppDiagnostics(recorder: recorder);

    await diagnostics.recordInfo(
      'perf.frame',
      'frame rendered',
      data: {'duration': 16.5},
    );

    expect(recorder.breadcrumbs, hasLength(1));
    final breadcrumb = recorder.breadcrumbs.single;
    expect(breadcrumb.category, 'perf.frame');
    expect(breadcrumb.type, 'default');
    expect(breadcrumb.message, 'frame rendered');
    expect(breadcrumb.level, SentryLevel.info);
    expect(breadcrumb.data?['duration'], 16.5);
  });

  test('startSpan creates transaction when currentSpan is null', () async {
    final recorder = _RecordingDiagnosticsRecorder();
    final diagnostics = AppDiagnostics(recorder: recorder);
    expect(recorder.currentSpan, isNull);

    final span = diagnostics.startSpan(
      'app.init',
      description: 'initialize app',
      data: {'phase': 'startup'},
      tags: {'feature': 'init'},
    );

    expect(recorder.currentSpan, isNotNull);
    final transaction = recorder.currentSpan as _RecordingSentrySpan;
    expect(transaction.operation, 'app.init');
    expect(transaction.description, 'initialize app');
    expect(transaction.data['phase'], 'startup');
    expect(transaction.tags['feature'], 'init');

    await span.finish(status: const SpanStatus.ok());
    expect(transaction.finished, isTrue);
    expect(transaction.status, const SpanStatus.ok());
  });

  test(
    'startSpan falls back to noop span when recorder span creation fails',
    () async {
      final diagnostics = AppDiagnostics(recorder: _FailingStartSpanRecorder());

      final span = diagnostics.startSpan(
        'schedule.refresh',
        description: 'refresh visible week',
        data: {'origin': 'userBrowsing'},
        tags: {'feature': 'schedule'},
      );

      expect(() => span.setData('key', 'value'), returnsNormally);
      expect(() => span.setTag('feature', 'schedule'), returnsNormally);
      expect(() => span.attachError(StateError('boom')), returnsNormally);
      await expectLater(span.finish(), completes);
    },
  );

  test(
    'AppDiagnosticsSpan.attachError records sanitized error data on span',
    () async {
      final recorder = _RecordingDiagnosticsRecorder();
      final diagnostics = AppDiagnostics(recorder: recorder);

      final span = diagnostics.startSpan('task.execute');
      final error = StateError(
        'login failed for jane@example.com with https://example.test/path?token=secret',
      );

      span.attachError(error);

      final sentrySpan = recorder.currentSpan as _RecordingSentrySpan;
      expect(sentrySpan.throwable, isNull);
      expect(sentrySpan.data['errorType'], 'StateError');
      expect(
        sentrySpan.data['errorMessage'],
        'Bad state: login failed for [redacted] with [redacted]',
      );
      expect(sentrySpan.status, const SpanStatus.internalError());

      await span.finish(status: const SpanStatus.internalError());
    },
  );

  test(
    'AppDiagnosticsSpan swallows errors from underlying span methods',
    () async {
      final recorder = _RecordingDiagnosticsRecorder();
      recorder.currentSpan = _ThrowingSentrySpan('parent');
      final diagnostics = AppDiagnostics(recorder: recorder);

      final span = diagnostics.startSpan('task.execute');

      expect(() => span.setData('phase', 'startup'), returnsNormally);
      expect(() => span.setTag('feature', 'task'), returnsNormally);
      expect(
        () => span.attachError(StateError('task failed')),
        returnsNormally,
      );
      await expectLater(span.finish(status: const SpanStatus.ok()), completes);
    },
  );
}

class _RecordingDiagnosticsRecorder implements DiagnosticsRecorder {
  final List<Breadcrumb> breadcrumbs = <Breadcrumb>[];
  final List<_CapturedException> capturedExceptions = <_CapturedException>[];
  ISentrySpan? currentSpan;

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    breadcrumbs.add(breadcrumb);
  }

  @override
  ISentrySpan? getCurrentSpan() => currentSpan;

  @override
  Future<void> captureException(
    Object exception,
    StackTrace stackTrace, {
    SentryMessage? message,
    Map<String, String> tags = const <String, String>{},
    Map<String, Object?> contexts = const <String, Object?>{},
  }) async {
    capturedExceptions.add(
      _CapturedException(
        exception: exception,
        stackTrace: stackTrace,
        message: message,
        tags: tags,
        contexts: contexts,
      ),
    );
  }

  @override
  ISentrySpan startTransaction(String operation, {String? description}) {
    final span = _RecordingSentrySpan(operation, description: description);
    currentSpan = span;
    return span;
  }
}

class _FailingDiagnosticsRecorder implements DiagnosticsRecorder {
  int breadcrumbAttempts = 0;
  int captureExceptionAttempts = 0;

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) {
    breadcrumbAttempts++;
    throw StateError('failed breadcrumb');
  }

  @override
  Future<void> captureException(
    Object exception,
    StackTrace stackTrace, {
    SentryMessage? message,
    Map<String, String> tags = const <String, String>{},
    Map<String, Object?> contexts = const <String, Object?>{},
  }) {
    captureExceptionAttempts++;
    throw StateError('failed exception capture');
  }

  @override
  ISentrySpan? getCurrentSpan() => null;

  @override
  ISentrySpan startTransaction(String operation, {String? description}) {
    return _RecordingSentrySpan(operation, description: description);
  }
}

class _FailingStartSpanRecorder implements DiagnosticsRecorder {
  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {}

  @override
  Future<void> captureException(
    Object exception,
    StackTrace stackTrace, {
    SentryMessage? message,
    Map<String, String> tags = const <String, String>{},
    Map<String, Object?> contexts = const <String, Object?>{},
  }) async {}

  @override
  ISentrySpan? getCurrentSpan() => null;

  @override
  ISentrySpan startTransaction(String operation, {String? description}) {
    throw StateError('failed startTransaction');
  }
}

class _CapturedException {
  final Object exception;
  final StackTrace stackTrace;
  final SentryMessage? message;
  final Map<String, String> tags;
  final Map<String, Object?> contexts;

  _CapturedException({
    required this.exception,
    required this.stackTrace,
    required this.message,
    required this.tags,
    required this.contexts,
  });
}

class _RecordingSentrySpan extends ISentrySpan {
  final String operation;
  final String? description;
  final Map<String, dynamic> data = <String, dynamic>{};
  final Map<String, String> tags = <String, String>{};
  final List<_RecordingSentrySpan> startedChildren = <_RecordingSentrySpan>[];

  _RecordingSentrySpan(this.operation, {this.description});

  @override
  DateTime? endTimestamp;

  @override
  bool finished = false;

  @override
  String? origin;

  @override
  SentryTracesSamplingDecision? get samplingDecision => null;

  @override
  DateTime startTimestamp = DateTime.now();

  @override
  SpanStatus? status;

  @override
  dynamic throwable;

  @override
  SentrySpanContext get context =>
      SentrySpanContext(operation: operation, description: description);

  @override
  Future<void> finish({
    SpanStatus? status,
    DateTime? endTimestamp,
    Hint? hint,
  }) async {
    this.status = status ?? this.status;
    this.endTimestamp = endTimestamp ?? DateTime.now();
    finished = true;
  }

  @override
  void removeData(String key) {
    data.remove(key);
  }

  @override
  void removeTag(String key) {
    tags.remove(key);
  }

  @override
  void scheduleFinish() {}

  @override
  void setData(String key, dynamic value) {
    data[key] = value;
  }

  @override
  void setMeasurement(String name, num value, {SentryMeasurementUnit? unit}) {}

  @override
  void setTag(String key, String value) {
    tags[key] = value;
  }

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) {
    final child = _RecordingSentrySpan(operation, description: description)
      ..startTimestamp = startTimestamp ?? DateTime.now();
    startedChildren.add(child);
    return child;
  }

  @override
  SentryBaggageHeader? toBaggageHeader() => null;

  @override
  SentryTraceHeader toSentryTrace() =>
      SentryTraceHeader(SentryId.newId(), SpanId.newId(), sampled: true);

  @override
  SentryTraceContextHeader? traceContext() => null;
}

class _ThrowingSentrySpan extends _RecordingSentrySpan {
  _ThrowingSentrySpan(super.operation);

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) {
    return _ThrowingSentrySpan(operation)
      ..startTimestamp = startTimestamp ?? DateTime.now();
  }

  @override
  void setData(String key, dynamic value) {
    throw StateError('failed setData');
  }

  @override
  void setTag(String key, String value) {
    throw StateError('failed setTag');
  }

  @override
  set throwable(dynamic value) {
    throw StateError('failed throwable');
  }

  @override
  Future<void> finish({
    SpanStatus? status,
    DateTime? endTimestamp,
    Hint? hint,
  }) async {
    throw StateError('failed finish');
  }
}
