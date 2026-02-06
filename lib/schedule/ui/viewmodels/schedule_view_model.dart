import 'dart:async';

import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class ScheduleViewModel extends BaseViewModel {
  final ScheduleSourceProvider _scheduleSourceProvider;
  Timer? _initialSetupTimer;
  bool _isDisposed = false;
  bool _initialized = false;

  bool _didSetupProperly = false;
  bool _isInitializingScheduleSource = true;
  bool _didAttemptSetup = false;

  bool get didSetupProperly => _didSetupProperly;
  bool get isInitializingScheduleSource => _isInitializingScheduleSource;
  bool get didAttemptSetup => _didAttemptSetup;

  ScheduleViewModel(this._scheduleSourceProvider);

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _isInitializingScheduleSource = true;
    notifyIfMounted("isInitializingScheduleSource");
    _scheduleSourceProvider
        .addDidChangeScheduleSourceCallback(onDidChangeScheduleSource);
    _didSetupProperly = _scheduleSourceProvider.didSetupCorrectly();
    _scheduleInitialSetup();
  }

  void _scheduleInitialSetup() {
    _initialSetupTimer?.cancel();
    _initialSetupTimer = Timer(const Duration(seconds: 1), () {
      if (_isDisposed) return;
      _didAttemptSetup = true;
      _isInitializingScheduleSource = true;
      notifyIfMounted("isInitializingScheduleSource");
      _scheduleSourceProvider.setupScheduleSource().then((_) {
        if (_isDisposed) return;
        if (_isInitializingScheduleSource) {
          _isInitializingScheduleSource = false;
          notifyIfMounted("isInitializingScheduleSource");
        }
      });
    });
  }

  void onDidChangeScheduleSource(ScheduleSource scheduleSource, bool valid) {
    if (_isDisposed) return;
    _didSetupProperly = valid;
    if (_isInitializingScheduleSource) {
      _isInitializingScheduleSource = false;
      notifyIfMounted("isInitializingScheduleSource");
    }
    notifyIfMounted("didSetupProperly");
  }

  @override
  void dispose() {
    _isDisposed = true;
    _initialSetupTimer?.cancel();
    _scheduleSourceProvider
        .removeDidChangeScheduleSourceCallback(onDidChangeScheduleSource);
    super.dispose();
  }
}
