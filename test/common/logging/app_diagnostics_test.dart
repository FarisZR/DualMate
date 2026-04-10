import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

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
    expect(
      (captured.contexts['diagnostics'] as Map<String, dynamic>)['operation'],
      'root.initialize',
    );
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
    expect(child.data['origin'], 'userBrowsing');
    expect(child.tags['feature'], 'schedule');

    await span.finish(status: const SpanStatus.ok());
    expect(child.finished, isTrue);
    expect(child.status, const SpanStatus.ok());
  });
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
    final child = _RecordingSentrySpan(
      operation,
      description: description,
    )..startTimestamp = startTimestamp ?? DateTime.now();
    startedChildren.add(child);
    return child;
  }

  @override
  SentryBaggageHeader? toBaggageHeader() => null;

  @override
  SentryTraceHeader toSentryTrace() => SentryTraceHeader(
        SentryId.newId(),
        SpanId.newId(),
        sampled: true,
      );

  @override
  SentryTraceContextHeader? traceContext() => null;
}
