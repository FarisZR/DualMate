import 'dart:async';

import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:flutter/widgets.dart';

class Analytics {
  Future<void> logEvent(
      {required String name, Map<String, Object>? parameters}) {
    return AppDiagnostics.instance.recordInfo(
      'analytics.event',
      name,
      data: parameters ?? const <String, Object>{},
    );
  }

  Future<void> logTutorialBegin() {
    return logEvent(name: 'tutorial_begin');
  }

  Future<void> logTutorialComplete() {
    return logEvent(name: 'tutorial_complete');
  }

  Future<void> setUserProperty({required String name, required String value}) {
    return AppDiagnostics.instance.recordInfo(
      'analytics.user_property',
      name,
      data: {'value': value},
    );
  }
}

final Analytics analytics = Analytics();

class _PerfAwareNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    unawaited(
      AppDiagnostics.instance.recordNavigation(
        route.settings.name ?? route.runtimeType.toString(),
        data: {
          'type': 'didPush',
          'from': previousRoute?.settings.name,
          'to': route.settings.name,
        },
      ),
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    unawaited(
      AppDiagnostics.instance.recordNavigation(
        previousRoute != null
            ? (previousRoute.settings.name ??
                previousRoute.runtimeType.toString())
            : 'unknown',
        data: {
          'type': 'didPop',
          'from': route.settings.name,
          'to': previousRoute?.settings.name,
        },
      ),
    );
  }
}

final NavigatorObserver rootNavigationObserver = _PerfAwareNavigatorObserver();

final NavigatorObserver mainNavigationObserver = _PerfAwareNavigatorObserver();
