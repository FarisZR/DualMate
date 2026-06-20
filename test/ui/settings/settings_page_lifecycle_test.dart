import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/common/application_constants.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/void_background_work_scheduler.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/ui/viewmodels/root_view_model.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:dualmate/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  setUp(() {
    KiwiContainer().clear();
    final preferencesProvider = _FakePreferencesProvider();
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
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  testWidgets(
    'prettify schedule toggle can be changed before settings route disposes',
    (tester) async {
      final rootViewModel = RootViewModel(KiwiContainer().resolve());
      await rootViewModel.loadFromPreferences();

      await tester.pumpWidget(_wrapWithApp(rootViewModel, SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Improve schedule entries'));
      await tester.pump();

      await tester.pumpWidget(_wrapWithApp(rootViewModel, const SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('about dialog shows privacy policy link and View licenses', (
    tester,
  ) async {
    final rootViewModel = RootViewModel(KiwiContainer().resolve());
    await rootViewModel.loadFromPreferences();

    final launchedUrls = <Uri>[];
    final fakeLauncher = _RecordingUrlLauncherPlatform()..urls = launchedUrls;
    UrlLauncherPlatform.instance = fakeLauncher;

    await tester.pumpWidget(_wrapWithApp(rootViewModel, SettingsPage()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('About this app'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('About this app'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(launchedUrls, [Uri.parse(ApplicationPrivacyPolicyUrl)]);

    expect(tester.takeException(), isNull);
  });
}

Widget _wrapWithApp(RootViewModel rootViewModel, Widget child) {
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
      home: child,
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

class _FakePreferencesProvider implements PreferencesProvider {
  bool _prettifySchedule = false;
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<T?> get<T>(String key) async => _values[key] as T?;

  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<AppTheme> appTheme() async => AppTheme.System;

  @override
  Future<bool> isFirstStart() async => false;

  @override
  Future<bool> getNotifyAboutNextDay() async => false;

  @override
  Future<bool> getNotifyAboutScheduleChanges() async => false;

  @override
  Future<bool> getPrettifySchedule() async => _prettifySchedule;

  @override
  Future<void> setPrettifySchedule(bool value) async {
    _prettifySchedule = value;
  }

  @override
  Future<bool> getUseDhMineForDates() async => false;

  @override
  Future<String?> getSelectedCanteenLocationId() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingUrlLauncherPlatform extends MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  late List<Uri> urls;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<void> closeWebView() async {}

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    urls.add(Uri.parse(url));
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(Uri.parse(url));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
