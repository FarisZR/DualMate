import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:flutter/foundation.dart';

class PerformanceOverlayController {
  static const String preferenceKey = "ShowPerformanceOverlay";
  static final ValueNotifier<bool> enabled = ValueNotifier(false);
  static bool _loaded = false;

  static Future<void> load(PreferencesProvider preferencesProvider) async {
    if (_loaded) return;
    final stored = await preferencesProvider.get<bool>(preferenceKey) ?? false;
    enabled.value = stored;
    _loaded = true;
  }

  static Future<void> setEnabled(
    PreferencesProvider preferencesProvider,
    bool value,
  ) async {
    enabled.value = value;
    await preferencesProvider.set<bool>(preferenceKey, value);
  }
}
