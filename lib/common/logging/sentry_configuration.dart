import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_scrubber.dart';

final String _sentryDsn = String.fromCharCodes(const <int>[
  104, 116, 116, 112, 115, 58, 47, 47, 99, 48, 54, 54, 98, 54, 101, 101,
  57, 97, 48, 54, 50, 55, 57, 55, 53, 54, 57, 57, 55, 56, 49, 101,
  98, 100, 102, 51, 55, 56, 98, 100, 64, 111, 52, 53, 49, 49, 49, 57,
  50, 54, 57, 51, 48, 49, 52, 53, 50, 56, 46, 105, 110, 103, 101, 115,
  116, 46, 100, 101, 46, 115, 101, 110, 116, 114, 121, 46, 105, 111, 47,
  52, 53, 49, 49, 49, 57, 50, 54, 57, 53, 48, 52, 54, 50, 50, 52,
]);
const String _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
const String _sentryEnvironment = String.fromEnvironment('SENTRY_ENVIRONMENT');

String get sentryDsn => _sentryDsn.trim();

bool isSentryConfigured({String? dsn}) {
  return (dsn ?? _sentryDsn).trim().isNotEmpty;
}

Future<void> configureSentryOptions(SentryFlutterOptions options) async {
  options.dsn = sentryDsn;
  options.debug = !kReleaseMode;
  options.diagnosticLevel = kReleaseMode ? SentryLevel.info : SentryLevel.debug;
  final trimmedEnvironment = _sentryEnvironment.trim();
  final trimmedRelease = _sentryRelease.trim();
  options.environment = trimmedEnvironment.isNotEmpty
      ? trimmedEnvironment
      : (kReleaseMode ? 'production' : 'debug');
  if (trimmedRelease.isNotEmpty) {
    options.release = trimmedRelease;
  }
  options.sendDefaultPii = false;
  options.enableLogs = false;
  options.enableAutoPerformanceTracing = true;
  options.enableFramesTracking = true;
  options.enableAutoSessionTracking = true;
  options.enableNativeCrashHandling = true;
  options.enableUserInteractionBreadcrumbs = false;
  options.enableUserInteractionTracing = false;
  options.attachScreenshot = false;
  options.tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
  options.replay.sessionSampleRate = 0.0;
  options.replay.onErrorSampleRate = 0.0;
  options.beforeSend = scrubSentryEvent;
  options.beforeSendTransaction = scrubSentryTransaction;
  options.beforeBreadcrumb = scrubSentryBreadcrumb;
}
