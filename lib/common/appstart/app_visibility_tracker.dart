import 'package:flutter/widgets.dart';

class AppVisibilityTracker {
  AppLifecycleState _state;

  AppVisibilityTracker({required AppLifecycleState initialState})
      : _state = initialState;

  AppLifecycleState get state => _state;

  bool get isAppAttended =>
      _state == AppLifecycleState.resumed ||
      _state == AppLifecycleState.inactive;

  void update(AppLifecycleState state) {
    _state = state;
  }
}
