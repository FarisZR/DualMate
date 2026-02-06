import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:flutter/foundation.dart';

class PerformanceOverlayController {
  static const String PreferenceKey = "ShowPerformanceOverlay";
  static final ValueNotifier<bool> enabled = ValueNotifier(false);
  static bool _loaded = false;

  PerformanceOverlayController._();

  static Future<void> load(PreferencesProvider preferencesProvider) async {
    if (!kDebugMode) return;
    if (_loaded) return;
    final stored = await preferencesProvider.get<bool>(PreferenceKey) ?? false;
    enabled.value = stored;
    _loaded = true;
  }

  static Future<void> setEnabled(
    PreferencesProvider preferencesProvider,
    bool value,
  ) async {
    if (!kDebugMode) return;
    enabled.value = value;
    _loaded = true;
    await preferencesProvider.set<bool>(PreferenceKey, value);
  }
}
