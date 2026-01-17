import 'dart:io';

import 'package:dhbwstudentapp/ui/root_page.dart';
import 'package:dhbwstudentapp/common/appstart/app_initializer.dart';
import 'package:dhbwstudentapp/common/data/preferences/preferences_provider.dart';
import 'package:dhbwstudentapp/common/logging/crash_reporting.dart';
import 'package:dhbwstudentapp/common/ui/viewmodels/root_view_model.dart';
import 'package:kiwi/kiwi.dart';
import 'package:flutter/material.dart';

import 'common/util/platform_util.dart';

///
/// Main entry point for the app
///
void main() async {
  // Setup the flutter bindings and the error reporting as early as possible
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    reportException(details.exception, details.stack);
  };

  await initializeApp(false);

  saveLastStartLanguage();

  await PlatformUtil.initializePortraitLandscapeMode();

  runApp(RootPage(
    rootViewModel: await loadRootViewModel(),
  ));
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

Future<RootViewModel> loadRootViewModel() async {
  var rootViewModel = RootViewModel(
    KiwiContainer().resolve(),
  );

  await rootViewModel.loadFromPreferences();
  return rootViewModel;
}
