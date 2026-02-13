import 'package:flutter/foundation.dart';

class MainSectionController {
  MainSectionController._();

  static final MainSectionController instance = MainSectionController._();

  final ValueNotifier<int> _routeSignal = ValueNotifier<int>(0);

  int _signalCounter = 0;
  String? _pendingRoute;

  ValueListenable<int> get routeSignal => _routeSignal;

  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  void openRoute(String route) {
    _pendingRoute = route;
    _signalCounter += 1;
    _routeSignal.value = _signalCounter;
  }
}
