import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/void_background_work_scheduler.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/ui/viewmodels/root_view_model.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:dualmate/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _onboardingMarker = '__onboarding_marker__';

void main() {
  late PreferencesProvider preferencesProvider;
  late _RecordingScheduleSourceProvider scheduleSourceProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KiwiContainer().clear();
    preferencesProvider =
        PreferencesProvider(PreferencesAccess(), SecureStorageAccess());
    scheduleSourceProvider = _RecordingScheduleSourceProvider();
    KiwiContainer().registerInstance<PreferencesProvider>(preferencesProvider);
    KiwiContainer().registerInstance<CanteenLocationService>(
      CanteenLocationService(preferencesProvider),
    );
    KiwiContainer().registerInstance<WorkSchedulerService>(
      VoidBackgroundWorkScheduler(),
    );
    KiwiContainer().registerInstance<TaskCallback>(
      _FakeTaskCallback(),
      name: NextDayInformationNotification.name,
    );
    KiwiContainer().registerInstance<NotificationApi>(VoidNotificationApi());
    KiwiContainer().registerInstance<ScheduleSourceProvider>(
      scheduleSourceProvider,
    );
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  testWidgets('replay onboarding tile is hidden until developer options unlock', (
    tester,
  ) async {
    final rootViewModel = RootViewModel(KiwiContainer().resolve());
    await rootViewModel.loadFromPreferences();

    await tester.pumpWidget(_wrapWithRoutes(rootViewModel));
    await tester.pumpAndSettle();

    expect(find.text('Replay onboarding'), findsNothing);
  });

  testWidgets(
    'replay onboarding clears schedule cache, sets first start and navigates',
    (tester) async {
      await preferencesProvider.setIsFirstStart(false);

      final rootViewModel = RootViewModel(preferencesProvider);
      await rootViewModel.loadFromPreferences();

      await tester.pumpWidget(_wrapWithRoutes(rootViewModel));
      await tester.pumpAndSettle();

      await _unlockDeveloperOptions(tester);

      expect(find.text('Replay onboarding'), findsOneWidget);

      await tester.tap(find.text('Replay onboarding'));
      await tester.pumpAndSettle();

      expect(find.text(_onboardingMarker), findsOneWidget);
      expect(await preferencesProvider.isFirstStart(), isTrue);
      expect(scheduleSourceProvider.clearScheduleCacheCalls, 1);
    },
  );
}

Future<void> _unlockDeveloperOptions(WidgetTester tester) async {
  final devTitle = find.text('Developer options');
  for (var i = 0; i < 6; i++) {
    await tester.ensureVisible(devTitle);
    await tester.tap(devTitle);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Widget _wrapWithRoutes(RootViewModel rootViewModel) {
  return PropertyChangeProvider<RootViewModel, String>(
    value: rootViewModel,
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: SettingsPage(),
      onGenerateRoute: (settings) {
        if (settings.name == 'onboarding') {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text(_onboardingMarker)),
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => Container());
      },
    ),
  );
}

class _FakeTaskCallback implements TaskCallback {
  @override
  Future<void> cancel() async {}

  @override
  String getName() => 'fake-task';

  @override
  Future<void> run() async {}

  @override
  Future<void> schedule() async {}
}

class _RecordingScheduleSourceProvider implements ScheduleSourceProvider {
  int clearScheduleCacheCalls = 0;

  @override
  Future<void> clearScheduleCache() async {
    clearScheduleCacheCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
