import 'package:flutter/widgets.dart';
import 'performance_telemetry.dart';

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
    PerformanceTelemetry.instance.markNavEvent(
      name: 'push:${route.settings.name ?? route.hashCode}',
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    PerformanceTelemetry.instance.markNavEvent(
      name: 'pop:${route.settings.name ?? route.hashCode}',
    );
    super.didPop(route, previousRoute);
  }
}

final NavigatorObserver rootNavigationObserver = _PerfAwareNavigatorObserver();

final NavigatorObserver mainNavigationObserver = _PerfAwareNavigatorObserver();
