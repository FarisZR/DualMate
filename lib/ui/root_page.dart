import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/analytics.dart';
import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/logging/perf_overlay_controller.dart';
import 'package:dualmate/common/logging/sentry_scrubber.dart';
import 'package:dualmate/common/appstart/interaction_idle_coordinator.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/ui/viewmodels/root_view_model.dart';
import 'package:dualmate/common/appstart/app_initializer.dart';
import 'package:dualmate/common/appstart/debug_startup_overrides.dart';
import 'package:dualmate/common/appstart/locale_preference_sync.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/launch_intent.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:kiwi/kiwi.dart';
import 'package:flutter/services.dart';
import 'package:dualmate/ui/navigation/main_section_controller.dart';
import 'package:dualmate/ui/navigation/navigator_key.dart';
import 'package:dualmate/ui/navigation/router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void _debugRootLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

void _debugRootError(String message, Object error, StackTrace trace) {
  if (kDebugMode) {
    debugPrint(message);
    debugPrint('$error');
    debugPrint('$trace');
  }
}

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
  static const Duration _foregroundCanteenPrewarmDelay = Duration(seconds: 15);

  RootViewModel? _rootViewModel;
  bool _backgroundInitStarted = false;
  bool _onboardingDeferredInitListenerAttached = false;
  Stopwatch? _deferredInitStopwatch;
  LocalePreferenceSync? _localePreferenceSync;
  final InteractionIdleCoordinator _interactionCoordinator =
      InteractionIdleCoordinator.instance;
  late final InteractionAwareNavigatorObserver _interactionNavigatorObserver;
  InteractionIdleTask? _backgroundInitializationTask;
  InteractionIdleTask? _foregroundHeavyInitializationTask;
  InteractionIdleTask? _canteenPreparationTask;
  static const MethodChannel _navigationChannel = MethodChannel(
    'com.fariszr.dualmate/navigation',
  );
  String? _pendingRoute;
  PerformanceTelemetryTask? _startupTask;
  bool _perfOverlayLoaded = false;

  @override
  void initState() {
    super.initState();
    _interactionNavigatorObserver = InteractionAwareNavigatorObserver(
      _interactionCoordinator,
    );
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
    _localePreferenceSync?.detach();
    _detachOnboardingDeferredInitListener();
    _backgroundInitializationTask?.cancel();
    _foregroundHeavyInitializationTask?.cancel();
    _canteenPreparationTask?.cancel();
    _interactionNavigatorObserver.dispose();
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
      if (kDebugMode) {
        debugPrint('Widget schedule payload received');
      }
      WidgetNavigationPayloadStore.instance.setSchedulePayload(schedulePayload);
    }

    final canteenPayload = WidgetCanteenDayPayload.fromMap(payload);
    if (!canteenPayload.isEmpty) {
      if (kDebugMode) {
        debugPrint('Widget canteen payload received');
      }
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
      _debugRootLog("Root init: base ${stopwatch.elapsedMilliseconds}ms");
      PerformanceTelemetry.instance.logInstant(
        'startup.root.base.done',
        args: {'elapsedMs': widget.startupStopwatch.elapsedMilliseconds},
      );

      await _applyDebugStartupOverrides();

      if (!mounted) return;

      _localePreferenceSync = LocalePreferenceSync(
        preferencesProvider: KiwiContainer().resolve<PreferencesProvider>(),
      );
      _localePreferenceSync!.attach();
      unawaited(_localePreferenceSync!.syncNow());
      _debugRootLog(
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

      _debugRootLog(
        "Root init: allow first frame ${stopwatch.elapsedMilliseconds}ms",
      );
      unawaited(_startupTask?.finish());
      unawaited(_loadRootPreferences(stopwatch));
    } catch (error, trace) {
      _debugRootError("Root init failed", error, trace);
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

  Future<void> _applyDebugStartupOverrides() async {
    if (!kDebugMode) return;

    final overrides = DebugStartupOverrides.fromEnvironment();
    if (!overrides.isActive) return;

    try {
      await overrides.apply(KiwiContainer().resolve<PreferencesProvider>());
      _debugRootLog("Root init: applied debug startup overrides");
    } catch (error, trace) {
      _debugRootError(
        "Root init: debug startup overrides failed",
        error,
        trace,
      );
      unawaited(
        AppDiagnostics.instance.reportCaughtException(
          error,
          trace,
          message: 'Root init: debug startup overrides failed',
          tags: {'feature': 'startup'},
          contexts: {
            'startup': {'phase': 'debug_overrides'},
          },
        ),
      );
    }
  }

  Future<void> _loadRootPreferences(Stopwatch stopwatch) async {
    try {
      await _rootViewModel?.loadFromPreferences();
      _debugRootLog("Root init: prefs ${stopwatch.elapsedMilliseconds}ms");
      PerformanceTelemetry.instance.logInstant(
        'startup.root.preferences.done',
        args: {'elapsedMs': widget.startupStopwatch.elapsedMilliseconds},
      );
    } catch (error, trace) {
      _debugRootError("Root init: prefs failed", error, trace);
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
      _debugRootError("Perf overlay load failed", error, trace);
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
                    _interactionNavigatorObserver,
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
      _backgroundInitializationTask = _interactionCoordinator.schedule(
        'startup.backgroundInit',
        () async {
          if (!mounted) return;
          await initializeAppBackground(false);
        },
        delay: _deferredBackgroundInitDelay,
      );
      await _backgroundInitializationTask!.future;
      if (!mounted) return;
      _debugRootLog(
        "Root init: deferred background ${stopwatch.elapsedMilliseconds}ms",
      );
      // Keep the old delays, but make their deadlines minimums. Interaction
      // and route/content animations can postpone the work safely.
      _foregroundHeavyInitializationTask = _interactionCoordinator.schedule(
        'startup.foregroundHeavyInit',
        () {
          if (!mounted) return Future<void>.value();
          return _runForegroundHeavyInitialization();
        },
        delay: _foregroundHeavyInitDelay,
      );
      // Canteen's page-level preparation owns its cache read. Reusing the
      // navigation entry here avoids a second startup refresh path.
      _canteenPreparationTask = _interactionCoordinator.schedule(
        'startup.canteenPreparation',
        () {
          if (!mounted) return Future<void>.value();
          return _runCanteenPrewarm();
        },
        delay: _foregroundCanteenPrewarmDelay,
      );
    } catch (error, trace) {
      _debugRootError("Root init: deferred background failed", error, trace);
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
      _debugRootError("Root init: foreground heavy failed", error, trace);
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

  Future<void> _runCanteenPrewarm() async {
    try {
      final canteenEntry = navigationEntries.firstWhere(
        (entry) => entry.route == 'canteen',
      );
      await canteenEntry.prepare();
    } catch (error, trace) {
      _debugRootError("Root init: canteen prewarm failed", error, trace);
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
