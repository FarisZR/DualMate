import 'dart:io';

import 'package:dualmate/ui/root_page.dart';
import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:kiwi/kiwi.dart';
import 'package:flutter/material.dart';

import 'common/util/platform_util.dart';

///
/// Main entry point for the app
///
void main() async {
  // Setup the flutter bindings and the error reporting as early as possible
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    reportException(details.exception, details.stack ?? StackTrace.current);
  };

  await PlatformUtil.initializePortraitLandscapeMode();

  runApp(const RootPage());
}

///
/// Save the current language in the preferences.
/// The language of the last app start is used for the background initialization.
/// When the app runs in the background this is an easy way to get the
/// used language
///

Future<void> saveLastStartLanguage() async {
  PreferencesProvider preferencesProvider = KiwiContainer().resolve();
  await preferencesProvider.setLastUsedLanguageCode(Platform.localeName);
}
