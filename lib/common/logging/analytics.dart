import 'package:flutter/widgets.dart';

class Analytics {
  Future<void> logEvent({String name, Map<String, Object> parameters}) async {}

  Future<void> logTutorialBegin() async {}

  Future<void> logTutorialComplete() async {}

  Future<void> setUserProperty({String name, String value}) async {}
}

final Analytics analytics = Analytics();

final NavigatorObserver rootNavigationObserver = NavigatorObserver();

final NavigatorObserver mainNavigationObserver = NavigatorObserver();
