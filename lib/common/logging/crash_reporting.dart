import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

Future<void> reportException(ex, StackTrace trace) async {
  if (kReleaseMode) {
    print("Reporting exception to crashlytics: $ex with stack trace $trace");
    try {
      await FirebaseCrashlytics.instance.recordError(ex, trace);
    } catch (e) {
      // Firebase Crashlytics not available (e.g., no Google Play Services)
      print("Could not report to Crashlytics (Firebase may not be available): $e");
    }
  } else {
    print(
        "Did not report exception (not in release mode) to crashlytics: $ex with stack trace $trace");
  }
}
