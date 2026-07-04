import 'package:dualmate/common/logging/sentry_configuration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('release trace sampling is disabled for cold-start performance', () {
    expect(sentryTraceSampleRate(releaseMode: true), isNull);
    expect(sentryTraceSampleRate(releaseMode: false), kDebugMode ? 1.0 : null);
  });

  test('privacy-sensitive Sentry features stay disabled', () async {
    final options = SentryFlutterOptions();

    await configureSentryOptions(options);

    expect(options.sendDefaultPii, isFalse);
    expect(options.enableLogs, isFalse);
    expect(options.attachScreenshot, isFalse);
    expect(options.replay.sessionSampleRate, 0.0);
    expect(options.replay.onErrorSampleRate, 0.0);
    expect(options.enableUserInteractionBreadcrumbs, isFalse);
    expect(options.enableUserInteractionTracing, isFalse);
    expect(options.enableAutoPerformanceTracing, kDebugMode);
    expect(options.enableFramesTracking, kDebugMode);
    expect(options.enableNativeTraceSync, kDebugMode);
    expect(options.enableAutoNativeBreadcrumbs, kDebugMode);
    expect(options.enableAppHangTracking, kDebugMode);
    expect(options.anrEnabled, kDebugMode);
    expect(options.tracesSampleRate, sentryTraceSampleRate());
    expect(options.beforeSend, isNotNull);
    expect(options.beforeSendTransaction, isNotNull);
    expect(options.beforeBreadcrumb, isNotNull);
    expect(options.diagnosticLevel, isA<SentryLevel>());
  });
}
