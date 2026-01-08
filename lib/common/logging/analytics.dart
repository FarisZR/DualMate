import 'package:firebase_analytics/firebase_analytics.dart';

// Wrapper class that safely handles Firebase Analytics when not available
class SafeFirebaseAnalytics {
  FirebaseAnalytics _analytics;
  bool _isAvailable = false;

  SafeFirebaseAnalytics() {
    try {
      _analytics = FirebaseAnalytics.instance;
      _isAvailable = true;
    } catch (e) {
      print("Firebase Analytics not available: $e");
      _isAvailable = false;
    }
  }

  Future<void> logEvent({String name, Map<String, Object> parameters}) async {
    if (_isAvailable && _analytics != null) {
      try {
        await _analytics.logEvent(name: name, parameters: parameters);
      } catch (e) {
        // Silently fail if analytics is not working
      }
    }
  }

  Future<void> setCurrentScreen({String screenName, String screenClassOverride}) async {
    if (_isAvailable && _analytics != null) {
      try {
        await _analytics.setCurrentScreen(screenName: screenName, screenClassOverride: screenClassOverride);
      } catch (e) {
        // Silently fail if analytics is not working
      }
    }
  }

  Future<void> setUserProperty({String name, String value}) async {
    if (_isAvailable && _analytics != null) {
      try {
        await _analytics.setUserProperty(name: name, value: value);
      } catch (e) {
        // Silently fail if analytics is not working
      }
    }
  }

  Future<void> logTutorialBegin() async {
    if (_isAvailable && _analytics != null) {
      try {
        await _analytics.logTutorialBegin();
      } catch (e) {
        // Silently fail if analytics is not working
      }
    }
  }

  Future<void> logTutorialComplete() async {
    if (_isAvailable && _analytics != null) {
      try {
        await _analytics.logTutorialComplete();
      } catch (e) {
        // Silently fail if analytics is not working
      }
    }
  }
}

final SafeFirebaseAnalytics analytics = SafeFirebaseAnalytics();

// Safe observer that won't crash if Firebase is not available
FirebaseAnalyticsObserver _createSafeObserver() {
  try {
    return FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
  } catch (e) {
    return null;
  }
}

final FirebaseAnalyticsObserver rootNavigationObserver = _createSafeObserver();

final FirebaseAnalyticsObserver mainNavigationObserver = _createSafeObserver();
