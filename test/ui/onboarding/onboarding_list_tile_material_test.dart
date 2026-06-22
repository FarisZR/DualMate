import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';
import 'package:dualmate/ui/onboarding/viewmodels/select_canteen_location_view_model.dart';
import 'package:dualmate/ui/onboarding/viewmodels/select_source_view_model.dart';
import 'package:dualmate/ui/onboarding/widgets/select_canteen_location_page.dart';
import 'package:dualmate/ui/onboarding/widgets/select_source_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'schedule source radios keep visible material effects under color',
    (tester) async {
      final preferencesProvider = PreferencesProvider(
        PreferencesAccess(),
        SecureStorageAccess(),
      );

      await tester.pumpWidget(
        _OnboardingTileHarness(
          viewModel: SelectSourceViewModel(preferencesProvider),
          child: const SelectSourcePage(),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canteen location radios keep visible material effects under color',
    (tester) async {
      final preferencesProvider = PreferencesProvider(
        PreferencesAccess(),
        SecureStorageAccess(),
      );

      await tester.pumpWidget(
        _OnboardingTileHarness(
          viewModel: SelectCanteenLocationViewModel(
            CanteenLocationService(preferencesProvider),
          ),
          child: const SelectCanteenLocationPage(),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}

class _OnboardingTileHarness extends StatelessWidget {
  const _OnboardingTileHarness({required this.viewModel, required this.child});

  final OnboardingStepViewModel viewModel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(
        body: ColoredBox(
          color: Colors.white,
          child: PropertyChangeProvider<OnboardingStepViewModel, String>(
            value: viewModel,
            child: child,
          ),
        ),
      ),
    );
  }
}
