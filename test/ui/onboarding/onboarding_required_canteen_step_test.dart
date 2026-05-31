import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KiwiContainer().clear();
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  test('required canteen step cannot be skipped when invalid', () async {
    final preferencesProvider =
        PreferencesProvider(PreferencesAccess(), SecureStorageAccess());
    final container = KiwiContainer();
    container.registerInstance<PreferencesProvider>(preferencesProvider);
    container.registerInstance<CanteenLocationService>(
      CanteenLocationService(preferencesProvider),
    );
    container.registerInstance<ScheduleSourceProvider>(_FakeScheduleSourceProvider());
    container.registerInstance<DualisService>(_FakeDualisService());

    final viewModel = OnboardingViewModel(
      preferencesProvider,
      () {},
    );

    await viewModel.nextPage();
    await viewModel.nextPage();
    await viewModel.nextPage();

    expect(viewModel.currentStep, 'canteenLocation');

    final canteenViewModel = viewModel.pages['canteenLocation']!.viewModel();
    canteenViewModel.setIsValid(false);

    await viewModel.nextPage();

    expect(viewModel.currentStep, 'canteenLocation');
  });
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDualisService implements DualisService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
