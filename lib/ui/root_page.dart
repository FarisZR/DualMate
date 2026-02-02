import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/analytics.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/ui/viewmodels/root_view_model.dart';
import 'package:dualmate/common/appstart/app_initializer.dart';
import 'package:dualmate/common/util/launch_intent.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/main.dart';
import 'package:kiwi/kiwi.dart';
import 'package:flutter/services.dart';
import 'package:dualmate/ui/navigation/navigator_key.dart';
import 'package:dualmate/ui/navigation/router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

///
/// This is the top level widget of the app. It handles navigation of the
/// root navigator and rebuilds its child widgets on theme changes
///
class RootPage extends StatefulWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  _RootPageState createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  RootViewModel? _rootViewModel;
  bool _isInitializing = true;
  bool _perfOverlayEnabled = false;
  bool _backgroundInitStarted = false;
  static const MethodChannel _navigationChannel =
      MethodChannel('com.fariszr.dualmate/navigation');
  String? _pendingRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationChannel.setMethodCallHandler(_handleNavigationCall);
    _fetchLaunchRoute();
    _fetchLaunchPayload();
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
          "Widget schedule payload: ${schedulePayload.dayStart} id=${schedulePayload.id}");
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
    await initializeAppBase(false);
    print("Root init: base ${stopwatch.elapsedMilliseconds}ms");

    await saveLastStartLanguage();
    print("Root init: save language ${stopwatch.elapsedMilliseconds}ms");
    _rootViewModel = RootViewModel(
      KiwiContainer().resolve(),
    );
    await _rootViewModel?.loadFromPreferences();
    print("Root init: prefs ${stopwatch.elapsedMilliseconds}ms");
    WidgetsBinding.instance.allowFirstFrame();

    _applyPendingRoute();

    print("Root init: allow first frame ${stopwatch.elapsedMilliseconds}ms");

    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_backgroundInitStarted) return;
      _backgroundInitStarted = true;
      _runDeferredInitialization(stopwatch);
    });
  }

  void _applyPendingRoute() {
    if (_pendingRoute == null) return;
    final navigator = NavigatorKey.mainKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyPendingRoute();
      });
      return;
    }

    var found = false;
    navigator.popUntil((route) {
      if (route.settings.name == _pendingRoute) {
        found = true;
        return true;
      }
      return route.isFirst;
    });

    if (!found) {
      navigator.pushNamed(_pendingRoute!);
    }
    _pendingRoute = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_rootViewModel == null) {
      return MaterialApp(
        home: const SizedBox.shrink(),
      );
    }

    return PropertyChangeProvider<RootViewModel, String>(
      child: PropertyChangeConsumer<RootViewModel, String>(
        properties: const ["appTheme", "isOnboarding"],
        builder: (
          BuildContext context,
          RootViewModel? model,
          Set<String>? properties,
        ) {
          if (model == null) return Container();
          return MaterialApp(
            theme: ColorPalettes.buildTheme(model.appTheme),
            showPerformanceOverlay: _perfOverlayEnabled,
            initialRoute:
                model.isOnboarding ? "onboarding" : _resolveInitialRoute(),
            navigatorKey: NavigatorKey.rootKey,
            navigatorObservers: [rootNavigationObserver],
            localizationsDelegates: [
              const LocalizationDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('de'),
            ],
            onGenerateRoute: generateRoute,
          );
        },
      ),
      value: _rootViewModel!,
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
      await initializeAppBackground(false);
      print(
          "Root init: deferred background ${stopwatch.elapsedMilliseconds}ms");
    } catch (error, trace) {
      print("Root init: deferred background failed");
      print(error);
      print(trace);
    }
  }
}
