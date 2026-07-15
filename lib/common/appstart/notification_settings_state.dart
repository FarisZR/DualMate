import 'package:flutter/foundation.dart';

enum NotificationSettingsStatus { loading, ready, unavailable, failed }

class NotificationSettingsState extends ChangeNotifier {
  NotificationSettingsStatus _status;
  Object? _error;

  NotificationSettingsState({
    NotificationSettingsStatus initialStatus =
        NotificationSettingsStatus.loading,
  }) : _status = initialStatus;

  NotificationSettingsStatus get status => _status;
  Object? get error => _error;
  bool get isReady => _status == NotificationSettingsStatus.ready;

  void markLoading() {
    _setStatus(NotificationSettingsStatus.loading);
  }

  void markReady() {
    _setStatus(NotificationSettingsStatus.ready);
  }

  void markUnavailable() {
    _setStatus(NotificationSettingsStatus.unavailable);
  }

  void markFailed(Object error) {
    _setStatus(NotificationSettingsStatus.failed, error: error);
  }

  void _setStatus(NotificationSettingsStatus status, {Object? error}) {
    if (_status == status && identical(_error, error)) {
      return;
    }
    _status = status;
    _error = error;
    notifyListeners();
  }
}
