import 'dart:async';
import 'dart:io';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:flutter/widgets.dart';

///
/// Keeps the persisted [PreferencesProvider.LastUsedLanguageCode] in sync with
/// runtime locale changes.
///
/// With Android 13+ per-app language, users can switch the app language from
/// system Settings while the app is running. `MainActivity` handles `locale`
/// via `android:configChanges`, so the process is not restarted and the
/// cold-start write in `RootPage._initializeApp` would otherwise stay stale.
/// The background/notification isolate reads this preference to render text, so
/// a runtime change must be persisted to avoid notifications appearing in the
/// old language until the next cold start.
///
/// Register it as a [WidgetsBindingObserver] via [attach]; it persists on
/// locale changes and when the app returns to the foreground.
///
class LocalePreferenceSync extends WidgetsBindingObserver {
  LocalePreferenceSync({
    required PreferencesProvider preferencesProvider,
    String Function()? currentLocaleName,
  })  : _preferencesProvider = preferencesProvider,
        _currentLocaleName = currentLocaleName ?? _platformLocaleName;

  final PreferencesProvider _preferencesProvider;
  final String Function() _currentLocaleName;

  static String _platformLocaleName() => Platform.localeName;

  /// Registers this observer with the [WidgetsBinding].
  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Removes this observer from the [WidgetsBinding].
  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Persists the current platform locale so the background isolate stays in
  /// sync with a runtime language change.
  Future<void> syncNow() async {
    try {
      await _preferencesProvider.setLastUsedLanguageCode(_currentLocaleName());
    } catch (error, trace) {
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Locale preference sync failed',
          tags: const {'feature': 'startup'},
          contexts: const {
            'startup': {'phase': 'language.sync'},
          },
        ),
      );
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    unawaited(syncNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncNow());
    }
  }
}
