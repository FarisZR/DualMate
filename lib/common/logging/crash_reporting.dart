import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:flutter/foundation.dart';

typedef ExceptionReporter = Future<void> Function(Object ex, StackTrace trace);

Future<void> reportExceptionToSentry(Object ex, StackTrace trace) async {
  await AppDiagnostics.instance.reportCaughtException(ex, trace);
}

ExceptionReporter reportExceptionImpl = reportExceptionToSentry;

Future<void> reportException(Object ex, StackTrace trace) async {
  if (kDebugMode) {
    debugPrint("Exception: $ex with stack trace $trace");
  }

  try {
    await reportExceptionImpl(ex, trace);
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint("Failed to report exception to Sentry: $error");
      debugPrint("$stackTrace");
    }
  }
}
