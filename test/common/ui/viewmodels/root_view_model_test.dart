import 'dart:async';

import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/ui/viewmodels/root_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadFromPreferences updates theme and onboarding state', () async {
    SharedPreferences.setMockInitialValues({
      PreferencesProvider.AppThemeKey: 'Dark',
      PreferencesProvider.IsFirstStartKey: true,
    });

    final viewModel = RootViewModel(
      PreferencesProvider(PreferencesAccess(), SecureStorageAccess()),
    );

    expect(viewModel.hasLoadedPreferences, isFalse);
    expect(viewModel.appTheme, AppTheme.System);
    expect(viewModel.isOnboarding, isFalse);

    await viewModel.loadFromPreferences();

    expect(viewModel.hasLoadedPreferences, isTrue);
    expect(viewModel.appTheme, AppTheme.Dark);
    expect(viewModel.isOnboarding, isTrue);
  });

  test('loadFromPreferences marks preferences loaded after async completion',
      () async {
    SharedPreferences.setMockInitialValues({
      PreferencesProvider.IsFirstStartKey: false,
    });

    final completer = Completer<SharedPreferences>();
    final viewModel = RootViewModel(
      PreferencesProvider(
        PreferencesAccess(instanceLoader: () => completer.future),
        SecureStorageAccess(),
      ),
    );

    final loadFuture = viewModel.loadFromPreferences();

    expect(viewModel.hasLoadedPreferences, isFalse);
    expect(viewModel.appTheme, AppTheme.System);
    expect(viewModel.isOnboarding, isFalse);

    completer.complete(await SharedPreferences.getInstance());
    await loadFuture;

    expect(viewModel.hasLoadedPreferences, isTrue);
    expect(viewModel.isOnboarding, isFalse);
  });
}
