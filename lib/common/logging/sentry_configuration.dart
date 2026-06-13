import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_scrubber.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');
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
