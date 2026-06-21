import 'package:dualmate/common/appstart/locale_preference_sync.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingPreferencesProvider preferences;
  late LocalePreferenceSync sync;

  setUp(() {
    preferences = _RecordingPreferencesProvider();
    sync = LocalePreferenceSync(
      preferencesProvider: preferences,
      currentLocaleName: () => 'de_DE',
    );
  });

  test('syncNow persists the current platform locale', () async {
    await sync.syncNow();

    expect(preferences.setLanguageCalls, ['de_DE']);
  });

  test('didChangeLocales triggers persistence of the current locale', () async {
    sync.didChangeLocales(const [Locale('de', 'DE')]);
    await Future<void>.delayed(Duration.zero);

    expect(preferences.setLanguageCalls, ['de_DE']);
  });

  test('resume triggers persistence of the current locale', () async {
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(preferences.setLanguageCalls, ['de_DE']);
  });

  test('non-resumed lifecycle states do not persist the locale', () async {
    for (final state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      sync.didChangeAppLifecycleState(state);
    }
    await Future<void>.delayed(Duration.zero);

    expect(preferences.setLanguageCalls, isEmpty);
  });
}

class _RecordingPreferencesProvider implements PreferencesProvider {
  final List<String> setLanguageCalls = <String>[];

  @override
  Future<void> setLastUsedLanguageCode(String languageCode) async {
    setLanguageCalls.add(languageCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected PreferencesProvider call: $invocation');
}
