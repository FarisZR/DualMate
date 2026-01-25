import 'dart:async';

import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class ScheduleViewModel extends BaseViewModel {
  final ScheduleSourceProvider _scheduleSourceProvider;
  Timer? _initialSetupTimer;
  bool _isDisposed = false;

  bool _didSetupProperly = false;

  bool get didSetupProperly => _didSetupProperly;

  ScheduleViewModel(this._scheduleSourceProvider) {
    _scheduleSourceProvider
        .addDidChangeScheduleSourceCallback(onDidChangeScheduleSource);
    _didSetupProperly = _scheduleSourceProvider.didSetupCorrectly();
    _scheduleInitialSetup();
  }

  void _scheduleInitialSetup() {
    _initialSetupTimer?.cancel();
    _initialSetupTimer = Timer(const Duration(seconds: 1), () {
      if (_isDisposed) return;
      _scheduleSourceProvider.setupScheduleSource();
    });
  }

  void onDidChangeScheduleSource(ScheduleSource scheduleSource, bool valid) {
    if (_isDisposed) return;
    _didSetupProperly = valid;
    notifyListeners("didSetupProperly");
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
