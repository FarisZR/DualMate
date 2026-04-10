import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:flutter/widgets.dart';

class Analytics {
  Future<void> logEvent(
      {required String name, Map<String, Object>? parameters}) async {}

  Future<void> logTutorialBegin() async {}

  Future<void> logTutorialComplete() async {}

  Future<void> setUserProperty(
      {required String name, required String value}) async {}
}

final Analytics analytics = Analytics();

class _PerfAwareNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    AppDiagnostics.instance.recordNavigation(
      route.settings.name ?? route.runtimeType.toString(),
      data: {
        'type': 'didPush',
        'from': previousRoute?.settings.name,
        'to': route.settings.name,
      },
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    AppDiagnostics.instance.recordNavigation(
      previousRoute?.settings.name ?? previousRoute.runtimeType.toString(),
      data: {
        'type': 'didPop',
        'from': route.settings.name,
        'to': previousRoute?.settings.name,
      },
    );
  }
}

final NavigatorObserver rootNavigationObserver = _PerfAwareNavigatorObserver();

final NavigatorObserver mainNavigationObserver = _PerfAwareNavigatorObserver();
