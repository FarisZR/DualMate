import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';

class RootViewModel extends BaseViewModel {
  final PreferencesProvider _preferencesProvider;

  late AppTheme _appTheme;
  AppTheme get appTheme => _appTheme;

  late bool _isOnboarding;
  bool get isOnboarding => _isOnboarding;

  RootViewModel(this._preferencesProvider) {
    _appTheme = AppTheme.System;
    _isOnboarding = false;
  }

  Future<void> loadFromPreferences() async {
    var darkMode = await _preferencesProvider.appTheme();

    _appTheme = darkMode;
    _isOnboarding = await _preferencesProvider.isFirstStart();

    notifyListeners("appTheme");
    notifyListeners("isOnboarding");
  }

  Future<void> setAppTheme(AppTheme value) async {
    await _preferencesProvider.setAppTheme(value);
    _appTheme = value;
    notifyListeners("appTheme");
  }

  void refreshSystemTheme() {
    if (_appTheme != AppTheme.System) return;
    notifyListeners("appTheme");
  }

  Future<void> setIsOnboarding(bool value) async {
    await _preferencesProvider.setIsFirstStart(value);
    _isOnboarding = value;
    notifyListeners("isOnboarding");
  }
}
