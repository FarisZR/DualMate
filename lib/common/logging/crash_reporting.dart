import 'package:dualmate/common/logging/app_diagnostics.dart';

Future<void> reportException(Object ex, StackTrace trace) async {
  print("Exception: $ex with stack trace $trace");

  try {
    await AppDiagnostics.instance.reportCaughtException(ex, trace);
  } catch (error, stackTrace) {
    print("Failed to report exception to Sentry: $error");
    print(stackTrace);
  }
}