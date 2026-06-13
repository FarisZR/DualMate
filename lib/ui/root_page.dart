import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/analytics.dart';
import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/logging/perf_overlay_controller.dart';
import 'package:dualmate/common/logging/sentry_scrubber.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/ui/viewmodels/root_view_model.dart';
import 'package:dualmate/common/appstart/app_initializer.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/launch_intent.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/main.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:kiwi/kiwi.dart';
import 'package:flutter/services.dart';
import 'package:dualmate/ui/navigation/main_section_controller.dart';
import 'package:dualmate/ui/navigation/navigator_key.dart';
import 'package:dualmate/ui/navigation/router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

///
/// This is the top level widget of the app. It handles navigation of the
/// root navigator and rebuilds its child widgets on theme changes
///
class RootPage extends StatefulWidget {
  final Stopwatch startupStopwatch;

  const RootPage({Key? key, required this.startupStopwatch}) : super(key: key);

  @override
  _RootPageState createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  static const Duration _deferredBackgroundInitDelay = Duration(
    milliseconds: 1800,
  );
  static const Duration _foregroundHeavyInitDelay = Duration(
    milliseconds: 2800,
  );
  static const Duration _foregroundCanteenPrewarmDelay = Duration(
    milliseconds: 7000,
  );

  RootViewModel? _rootViewModel;
  bool _backgroundInitStarted = false;
  bool _onboardingDeferredInitListenerAttached = false;
  Stopwatch? _deferredInitStopwatch;
  static const MethodChannel _navigationChannel = MethodChannel(
    'com.fariszr.dualmate/navigation',
  );
  String? _pendingRoute;
  PerformanceTelemetryTask? _startupTask;
  bool _perfOverlayLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationChannel.setMethodCallHandler(_handleNavigationCall);
    _fetchLaunchRoute();
    _fetchLaunchPayload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPerfOverlayPreference();
    });
    PerformanceTelemetry.instance.ensureFrameTimingListenerAttached();
    _startupTask = PerformanceTelemetry.instance.startTask(
      'startup.initialize',
    );
    unawaited(_setAppAttended(true));
    _initializeApp();
  }

  @override
  void dispose() {
    unawaited(_setAppAttended(false));
    _detachOnboardingDeferredInitListener();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_setAppAttended(_isAttendedState(state)));
    if (state == AppLifecycleState.resumed) {
      _fetchLaunchRoute();
      _fetchLaunchPayload();
    }
  }

  @override
  void didChangePlatformBrightness() {
    _rootViewModel?.refreshSystemTheme();
  }

  Future<void> _fetchLaunchRoute() async {
    try {
      final route = await _navigationChannel.invokeMethod<String>(
        'getLaunchRoute',
      );
      if (route != null && route.isNotEmpty) {
        _pendingRoute = route;
        _applyPendingRoute();
        await _navigationChannel.invokeMethod('clearLaunchRoute');
      }
    } on PlatformException {}
  }

  Future<void> _handleNavigationCall(MethodCall call) async {
    if (call.method == 'openRoute') {
      if (call.arguments is Map) {
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final route = arguments["route"] as String?;
        _storeWidgetPayload(arguments["payload"]);
        if (route == null || route.isEmpty) return;
        _pendingRoute = route;
        _clearPendingLaunchIntent();
        _applyPendingRoute();
        return;
      }
      final route = call.arguments as String?;
      if (route == null || route.isEmpty) return;
      _pendingRoute = route;
      _clearPendingLaunchIntent();
      _applyPendingRoute();
      return;
    }

    if (call.method == 'openWidgetPayload') {
      _storeWidgetPayload(call.arguments);
      return;
    }
  }

  Future<void> _fetchLaunchPayload() async {
    try {
      final payload = await _navigationChannel.invokeMethod('getLaunchPayload');
      _storeWidgetPayload(payload);
      if (payload != null) {
        await _navigationChannel.invokeMethod('clearLaunchPayload');
      }
    } on PlatformException {}
  }

  Future<void> _clearPendingLaunchIntent() async {
    try {
      await _navigationChannel.invokeMethod('clearLaunchRoute');
      await _navigationChannel.invokeMethod('clearLaunchPayload');
    } on PlatformException {}
  }

  void _storeWidgetPayload(dynamic payload) {
    if (payload is! Map) return;
    final schedulePayload = WidgetScheduleEntryPayload.fromMap(payload);
    if (!schedulePayload.isEmpty) {
      print(
        "Widget schedule payload: ${schedulePayload.dayStart} id=${schedulePayload.id}",
      );
      WidgetNavigationPayloadStore.instance.setSchedulePayload(schedulePayload);
    }

    final canteenPayload = WidgetCanteenDayPayload.fromMap(payload);
    if (!canteenPayload.isEmpty) {
      print("Widget canteen payload: ${canteenPayload.dayStart}");
      WidgetNavigationPayloadStore.instance.setCanteenPayload(canteenPayload);
    }
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();
    PerformanceTelemetry.instance.logInstant(
      'startup.initialize.start',
      args: {'elapsedMs': widget.startupStopwatch.elapsedMilliseconds},
    );
    PerformanceTelemetry.instance.logInstant(
      'startup.root.init.start',
      args: {'elapsedMs': widget.startupStopwatch.elapsedMilliseconds},
    );
    try {
      await initializeAppBase(false);
      await _setAppAttended(true);
      print("Root init: base ${stopwatch.elapsedMilliseconds}ms");
      PerformanceTelemetry.instance.logInstant(
        'startup.root.base.done',
        args: {'elapsedMs': widget.startupStopwatch.elapsedMilliseconds},
      );

      unawaited(_saveLastStartLanguage());
      print(
        "Root init: save language deferred ${stopwatch.elapsedMilliseconds}ms",
      );
      PerformanceTelemetry.instance.logInstant(
        'startup.root.language.done',
        args: {'elapsedMs': widget.startupStopwatch.elapsedMilliseconds},
      );
      _rootViewModel ??= RootViewModel(KiwiContainer().resolve());
      if (!mounted) {
        return;
      }
      setState(() {});

      _applyPendingRoute();

      print("Root init: allow first frame ${stopwatch.elapsedMilliseconds}ms");
      unawaited(_startupTask?.finish());
      unawaited(_loadRootPreferences(stopwatch));
    } catch (error, trace) {
      print("Root init failed");
      print(error);
      print(trace);
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Root init failed',
          tags: {'feature': 'startup'},
          contexts: {
            'startup': {
              'phase': 'root.initialize',
              'elapsedMs': widget.startupStopwatch.elapsedMilliseconds,
            },
          },
        ),
      );
      unawaited(_startupTask?.fail(error));

      if (_rootViewModel == null) {
        _rootViewModel = RootViewModel(KiwiContainer().resolve());
      }

      if (mounted) {
        setState(() {});
      }
    }
  }

  bool _isAttendedState(AppLifecycleState state) {
    return state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  Future<void> _setAppAttended(bool attended) async {
    try {
      await KiwiContainer().resolve<PreferencesProvider>().setIsAppAttended(
        attended,
      );
    } catch (_) {}
  }

  Future<void> _loadRootPreferences(Stopwatch stopwatch) async {
    try {
      await _rootViewModel?.loadFromPreferences();
      print("Root init: prefs ${stopwatch.elapsedMilliseconds}ms");
      PerformanceTelemetry.instance.logInstant(
        'startup.root.preferences.done',
        args: {'elapsedMs': widget.startupStopwatch.elapsedMilliseconds},
      );
    } catch (error, trace) {
      print("Root init: prefs failed");
      print(error);
      print(trace);
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Root init: prefs failed',
          tags: {'feature': 'startup'},
          contexts: {
            'startup': {'phase': 'root.preferences'},
          },
        ),
      );
    }

    if (!mounted) {
      return;
    }

    _deferredInitStopwatch = stopwatch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _backgroundInitStarted) return;
      if (!(_rootViewModel?.hasLoadedPreferences ?? false)) return;
      if (_rootViewModel?.isOnboarding ?? false) {
        _attachOnboardingDeferredInitListener();
        return;
      }
      _startDeferredInitialization();
    });
  }

  Future<void> _loadPerfOverlayPreference() async {
    if (_perfOverlayLoaded) return;
    try {
      final preferencesProvider = KiwiContainer()
          .resolve<PreferencesProvider>();
      await PerformanceOverlayController.load(preferencesProvider);
      _perfOverlayLoaded = true;
    } catch (error, trace) {
      print("Perf overlay load failed");
      print(error);
      print(trace);
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Perf overlay load failed',
          tags: {'feature': 'diagnostics'},
          contexts: {
            'diagnostics': {'phase': 'perf_overlay.load'},
          },
        ),
      );
      _perfOverlayLoaded = true;
    }
  }

  Future<void> _saveLastStartLanguage() async {
    try {
      await saveLastStartLanguage();
    } catch (error, trace) {
      print("Root init: save language failed");
      print(error);
      print(trace);
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Root init: save language failed',
          tags: {'feature': 'startup'},
          contexts: {
            'startup': {'phase': 'language.save'},
          },
        ),
      );
    }
  }

  void _applyPendingRoute() {
    final route = _pendingRoute;
    if (route == null) return;
    MainSectionController.instance.openRoute(route);
    _pendingRoute = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_rootViewModel == null) {
      return _buildStartupPlaceholder();
    }

    return PropertyChangeProvider<RootViewModel, String>(
      child: PropertyChangeConsumer<RootViewModel, String>(
        properties: const ["appTheme", "isOnboarding", "hasLoadedPreferences"],
        builder:
            (
              BuildContext context,
              RootViewModel? model,
              Set<String>? properties,
            ) {
              if (model == null) return Container();
              if (!model.hasLoadedPreferences) {
                return _buildStartupPlaceholder();
              }
              return ValueListenableBuilder<bool>(
                valueListenable: PerformanceOverlayController.enabled,
                builder: (context, perfEnabled, _) => MaterialApp(
                  theme: ColorPalettes.buildTheme(model.appTheme),
                  showPerformanceOverlay: perfEnabled,
                  initialRoute: model.isOnboarding
                      ? "onboarding"
                      : _resolveInitialRoute(),
                  navigatorKey: NavigatorKey.rootKey,
                  navigatorObservers: [
                    SentryNavigatorObserver(
                      setRouteNameAsTransaction: true,
                      enableAutoTransactions: true,
                      autoFinishAfter: const Duration(seconds: 5),
                      ignoreRoutes: const ['main'],
                      routeNameExtractor: sanitizeSentryRouteSettings,
                      additionalInfoProvider: (_, __) =>
                          const <String, dynamic>{'source': 'navigator'},
                    ),
                    rootNavigationObserver,
                  ],
                  localizationsDelegates: [
                    const LocalizationDelegate(),
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    DefaultCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [Locale('en'), Locale('de')],
                  onGenerateRoute: generateRoute,
                ),
              );
            },
      ),
      value: _rootViewModel!,
    );
  }

  Widget _buildStartupPlaceholder() {
    return MaterialApp(
      home: const ColoredBox(
        color: Color(0xFFFFFFFF),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  String _resolveInitialRoute() {
    var defaultRoute = "main";
    if (WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
        LaunchIntent.canteen) {
      return "main";
    }
    if (WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
        LaunchIntent.schedule) {
      return "main";
    }
    return defaultRoute;
  }

  Future<void> _runDeferredInitialization(Stopwatch stopwatch) async {
    try {
      // Allow first-frame interaction and navigation transitions to settle.
      await Future.delayed(_deferredBackgroundInitDelay);
      if (!mounted) return;
      await SchedulerBinding.instance.scheduleTask<void>(
        () async {
          if (!mounted) return;
          await initializeAppBackground(false);
        },
        Priority.idle,
        debugLabel: 'startup.backgroundInit',
      );
      print(
        "Root init: deferred background ${stopwatch.elapsedMilliseconds}ms",
      );
      SchedulerBinding.instance.scheduleTask<void>(
        () {
          unawaited(_prewarmScheduleCache());
        },
        Priority.idle,
        debugLabel: 'startup.scheduleCachePrewarm',
      );
      // Delay foreground-heavy tasks to keep startup animations responsive.
      Future.delayed(_foregroundHeavyInitDelay, () {
        if (!mounted) return;
        _runForegroundHeavyInitialization();
      });
      // Defer canteen prewarm further and run at idle priority.
      Future.delayed(_foregroundCanteenPrewarmDelay, () {
        if (!mounted) return;
        _scheduleIdleCanteenPrewarm();
      });
    } catch (error, trace) {
      print("Root init: deferred background failed");
      print(error);
      print(trace);
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Root init: deferred background failed',
          tags: {'feature': 'startup'},
          contexts: {
            'startup': {'phase': 'background.initialize'},
          },
        ),
      );
    }
  }

  Future<void> _runForegroundHeavyInitialization() async {
    try {
      await initializeAppForegroundHeavy();
    } catch (error, trace) {
      print("Root init: foreground heavy failed");
      print(error);
      print(trace);
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Root init: foreground heavy failed',
          tags: {'feature': 'startup'},
          contexts: {
            'startup': {'phase': 'foreground_heavy.initialize'},
          },
        ),
      );
    }
  }

  void _scheduleIdleCanteenPrewarm() {
    SchedulerBinding.instance.scheduleTask<void>(
      () {
        unawaited(_runCanteenPrewarm());
      },
      Priority.idle,
      debugLabel: 'startup.canteenPrewarm',
    );
  }

  Future<void> _runCanteenPrewarm() async {
    try {
      await prewarmCanteenIfStale();
    } catch (error, trace) {
      print("Root init: canteen prewarm failed");
      print(error);
      print(trace);
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Root init: canteen prewarm failed',
          tags: {'feature': 'canteen'},
          contexts: {
            'canteen': {'phase': 'startup_prewarm'},
          },
        ),
      );
    }
  }

  Future<void> _prewarmScheduleCache() async {
    try {
      final scheduleProvider = KiwiContainer().resolve<ScheduleProvider>();
      final start = toStartOfDay(toDayOfWeek(DateTime.now(), DateTime.monday));
      final end = toNextWeek(start);
      await scheduleProvider.warmScheduleCache(start, end);
    } catch (error, trace) {
      print("Root init: schedule cache warm failed");
      print(error);
      print(trace);
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Root init: schedule cache warm failed',
          tags: {'feature': 'schedule'},
          contexts: {
            'schedule': {'phase': 'startup_cache_warm'},
          },
        ),
      );
    }
  }

  void _attachOnboardingDeferredInitListener() {
    if (_onboardingDeferredInitListenerAttached || _rootViewModel == null) {
      return;
    }

    _onboardingDeferredInitListenerAttached = true;
    _rootViewModel!.addListener(_onOnboardingStateChanged, const [
      "isOnboarding",
    ]);
  }

  void _detachOnboardingDeferredInitListener() {
    if (!_onboardingDeferredInitListenerAttached || _rootViewModel == null) {
      return;
    }

    _onboardingDeferredInitListenerAttached = false;
    _rootViewModel!.removeListener(_onOnboardingStateChanged, const [
      "isOnboarding",
    ]);
  }

  void _onOnboardingStateChanged() {
    if (!mounted || _backgroundInitStarted) return;
    if (_rootViewModel?.isOnboarding ?? true) return;

    _detachOnboardingDeferredInitListener();
    _startDeferredInitialization();
  }

  void _startDeferredInitialization() {
    if (!mounted || _backgroundInitStarted) return;

    _backgroundInitStarted = true;
    final stopwatch = _deferredInitStopwatch ?? (Stopwatch()..start());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runDeferredInitialization(stopwatch));
    });
  }
}
