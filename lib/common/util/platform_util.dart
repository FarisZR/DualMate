import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef FlutterViewProvider = FlutterView Function();
typedef PreferredOrientationsSetter =
    Future<void> Function(List<DeviceOrientation> orientations);

class PlatformUtil {
  static final AdaptiveOrientationLock _orientationLock =
      AdaptiveOrientationLock();

  static FlutterView _implicitView() =>
      WidgetsBinding.instance.platformDispatcher.implicitView!;

  static bool isPhone() {
    final data = MediaQueryData.fromView(_implicitView());
    return data.size.shortestSide < 600;
  }

  static bool isTablet() {
    return !isPhone();
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static Brightness platformBrightness() {
    final data = MediaQueryData.fromView(_implicitView());
    return data.platformBrightness;
  }

  static Future<void> initializePortraitLandscapeMode() async {
    await _orientationLock.attach();
  }

  static bool isAndroid() {
    return Platform.isAndroid;
  }
}

class AdaptiveOrientationLock with WidgetsBindingObserver {
  AdaptiveOrientationLock({
    FlutterViewProvider? viewProvider,
    PreferredOrientationsSetter? setPreferredOrientations,
  }) : _viewProvider =
           viewProvider ??
           (() => WidgetsBinding.instance.platformDispatcher.implicitView!),
       _setPreferredOrientations =
           setPreferredOrientations ?? SystemChrome.setPreferredOrientations;

  static const double phoneShortestSideBreakpointDp = 600;

  final FlutterViewProvider _viewProvider;
  final PreferredOrientationsSetter _setPreferredOrientations;

  bool _isAttached = false;
  List<DeviceOrientation>? _lastAppliedOrientations;

  Future<void> attach() async {
    if (!_isAttached) {
      WidgetsBinding.instance.addObserver(this);
      _isAttached = true;
    }
    await update();
  }

  void detach() {
    if (!_isAttached) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _isAttached = false;
    _lastAppliedOrientations = null;
  }

  @override
  void didChangeMetrics() {
    unawaited(update());
  }

  Future<void> update() async {
    final orientations = preferredOrientationsForDisplay(
      _viewProvider().display,
    );
    if (_sameOrientations(_lastAppliedOrientations, orientations)) {
      return;
    }
    _lastAppliedOrientations = List.unmodifiable(orientations);
    await _setPreferredOrientations(orientations);
  }

  static bool isPhoneSizedDisplay(Display display) {
    final logicalDisplaySize = display.size / display.devicePixelRatio;
    return logicalDisplaySize.shortestSide < phoneShortestSideBreakpointDp;
  }

  static List<DeviceOrientation> preferredOrientationsForDisplay(
    Display display,
  ) {
    if (isPhoneSizedDisplay(display)) {
      return const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ];
    }
    return const [];
  }

  static bool _sameOrientations(
    List<DeviceOrientation>? previous,
    List<DeviceOrientation> next,
  ) {
    if (previous == null || previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index] != next[index]) {
        return false;
      }
    }
    return true;
  }
}
