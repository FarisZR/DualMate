import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    KiwiContainer().clear();

    // Secure storage uses a platform channel; stub it so DualisLoginViewModel
    // .save() does not throw during finishOnboarding().
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  test('finishOnboarding re-syncs the schedule source after step saves',
      () async {
    final preferencesProvider =
        PreferencesProvider(PreferencesAccess(), SecureStorageAccess());
    final scheduleSourceProvider = _RecordingScheduleSourceProvider();
    final container = KiwiContainer();
    container.registerInstance<PreferencesProvider>(preferencesProvider);
    container.registerInstance<CanteenLocationService>(
      CanteenLocationService(preferencesProvider),
    );
    container.registerInstance<ScheduleSourceProvider>(
      scheduleSourceProvider,
    );
    container.registerInstance<DualisService>(_FakeDualisService());

    final viewModel = OnboardingViewModel(
      preferencesProvider,
      scheduleSourceProvider,
      () {},
    );

    // Navigate to the last step (canteenLocation) via the default Rapla path.
    await viewModel.nextPage(); // selectSource -> rapla
    await viewModel.nextPage(); // rapla -> dualis
    await viewModel.nextPage(); // dualis -> canteenLocation

    expect(viewModel.currentStep, 'canteenLocation');

    // Make the canteen step valid so nextPage() triggers finishOnboarding.
    final canteenViewModel = viewModel.pages['canteenLocation']!.viewModel();
    canteenViewModel.setIsValid(true);

    await viewModel.nextPage();

    expect(scheduleSourceProvider.setupScheduleSourceCalls, 1);
  });
}

class _RecordingScheduleSourceProvider implements ScheduleSourceProvider {
  int setupScheduleSourceCalls = 0;

  @override
  Future<bool> setupScheduleSource() async {
    setupScheduleSourceCalls += 1;
    return true;
  }

  @override
  Future<void> setupForRapla(
    String url, {
    bool clearCachedEntries = true,
    bool setupSource = true,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeDualisService implements DualisService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
