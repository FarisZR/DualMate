import 'dart:async';
import 'dart:math';

import 'package:dhbwstudentapp/common/ui/viewmodels/base_view_model.dart';
import 'package:dhbwstudentapp/common/util/cancelable_mutex.dart';
import 'package:dhbwstudentapp/common/util/cancellation_token.dart';
import 'package:dhbwstudentapp/common/util/date_utils.dart';
import 'package:dhbwstudentapp/schedule/business/schedule_provider.dart';
import 'package:dhbwstudentapp/schedule/business/schedule_source_provider.dart';
import 'package:dhbwstudentapp/schedule/model/schedule.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_query_result.dart';
import 'package:dhbwstudentapp/schedule/service/schedule_source.dart';
import 'package:flutter/foundation.dart';

class WeeklyScheduleViewModel extends BaseViewModel {
  static const Duration weekDuration = Duration(days: 7);

  final ScheduleProvider scheduleProvider;
  final ScheduleSourceProvider scheduleSourceProvider;

  late DateTime currentDateStart;
  late DateTime currentDateEnd;

  bool _hasCurrentDateRange = false;

  DateTime? clippedDateStart;
  DateTime? clippedDateEnd;

  bool didUpdateScheduleIntoFuture = true;

  int displayStartHour = 7;
  int displayEndHour = 17;

  bool _hasQueryErrors = false;

  bool get hasQueryErrors => _hasQueryErrors;

  VoidCallback? _queryFailedCallback;

  bool updateFailed = false;

  bool isUpdating = false;
  DateTime? _lastUpdateRequest;
  Schedule? weekSchedule;

  String? scheduleUrl;

  DateTime get now => DateTime.now();

  Timer? _errorResetTimer;
  Timer? _updateNowTimer;

  bool _isDisposed = false;

  final CancelableMutex _updateMutex = CancelableMutex();

  late DateTime lastRequestedStart;
  late DateTime lastRequestedEnd;

  WeeklyScheduleViewModel(
    this.scheduleProvider,
    this.scheduleSourceProvider,
  ) {
    _initViewModel();
  }

  Future<void> _initViewModel() async {
    currentDateStart =
        toStartOfDay(toDayOfWeek(DateTime.now(), DateTime.monday));
    currentDateEnd = toNextWeek(currentDateStart);
    var cachedSchedule = await scheduleProvider.getCachedSchedule(
        currentDateStart, currentDateEnd);
    _setSchedule(cachedSchedule, currentDateStart, currentDateEnd);
    _scheduleInitialRefresh();
    ensureUpdateNowTimerRunning();

    scheduleSourceProvider
        .addDidChangeScheduleSourceCallback(_onDidChangeScheduleSource);
  }

  void _scheduleInitialRefresh() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isDisposed) return;
      updateSchedule(currentDateStart, currentDateEnd);
    });
  }

  Future<void> _onDidChangeScheduleSource(
    ScheduleSource newSource,
    bool setupSuccess,
  ) async {
    if (setupSuccess) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isDisposed) return;
        updateSchedule(currentDateStart, currentDateEnd);
      });
    }
  }

  void _setSchedule(Schedule? schedule, DateTime start, DateTime end) {
    weekSchedule = schedule;
    if (_hasCurrentDateRange) {
      didUpdateScheduleIntoFuture = currentDateStart.isBefore(start);
    } else {
      didUpdateScheduleIntoFuture = false;
      _hasCurrentDateRange = true;
    }
    currentDateStart = start;
    currentDateEnd = end;

    if (weekSchedule != null) {
      var scheduleStart = weekSchedule!.getStartDate();
      var scheduleEnd = weekSchedule!.getEndDate();

      if (scheduleStart == null || scheduleEnd == null) {
        clippedDateStart = toDayOfWeek(start, DateTime.monday);
        clippedDateEnd = toDayOfWeek(start, DateTime.friday);
      } else {
        clippedDateStart = toDayOfWeek(scheduleStart, DateTime.monday);
        clippedDateEnd = toDayOfWeek(scheduleEnd, DateTime.friday);
      }

      if (scheduleEnd != null && scheduleEnd.isAfter(clippedDateEnd!)) {
        clippedDateEnd = scheduleEnd;
      }

      displayStartHour = weekSchedule?.getStartTime()?.hour ?? 23;
      displayStartHour = min(7, displayStartHour);

      displayEndHour = weekSchedule?.getEndTime()?.hour ?? 0;
      displayEndHour = max(displayEndHour + 1, 17);
    } else {
      clippedDateStart = toDayOfWeek(currentDateStart, DateTime.monday);
      clippedDateEnd = toDayOfWeek(currentDateEnd, DateTime.friday);
    }

    notifyListeners("weekSchedule");
  }

  Future nextWeek() async {
    await updateSchedule(
      toNextWeek(currentDateStart),
      toNextWeek(currentDateEnd),
    );
  }

  Future previousWeek() async {
    await updateSchedule(
      toPreviousWeek(currentDateStart),
      toPreviousWeek(currentDateEnd),
    );
  }

  Future goToToday() async {
    currentDateStart =
        toStartOfDay(toDayOfWeek(DateTime.now(), DateTime.monday));
    currentDateEnd = toNextWeek(currentDateStart);

    await updateSchedule(currentDateStart, currentDateEnd);
  }

  Future updateSchedule(DateTime start, DateTime end) async {
    var now = DateTime.now();
    if (_lastUpdateRequest != null &&
        now.difference(_lastUpdateRequest!).inSeconds < 2) {
      return;
    }
    _lastUpdateRequest = now;

    lastRequestedEnd = end;
    lastRequestedStart = start;

    await _updateMutex.acquireAndCancelOther();

    if (lastRequestedStart != start || lastRequestedEnd != end) {
      _updateMutex.release();
      return;
    }

    try {
      isUpdating = true;
      notifyListeners("isUpdating");

      await _doUpdateSchedule(start, end);
    } catch (_) {
    } finally {
      isUpdating = false;
      _updateMutex.release();
      notifyListeners("isUpdating");
    }
  }

  Future _doUpdateSchedule(DateTime start, DateTime end) async {
    print("Refreshing schedule...");

    var cancellationToken = _updateMutex.token;

    scheduleUrl = null;

    var cachedSchedule = await scheduleProvider.getCachedSchedule(start, end);
    cancellationToken.throwIfCancelled();
    _setSchedule(cachedSchedule, start, end);

    var updatedSchedule = await _readScheduleFromService(
      start,
      end,
      cancellationToken,
    );
    cancellationToken.throwIfCancelled();

    if (updatedSchedule != null) {
      var schedule = updatedSchedule.schedule;

      _setSchedule(schedule, start, end);

      _hasQueryErrors = updatedSchedule.hasError;
      notifyListeners("hasQueryErrors");

      if (updatedSchedule.hasError) {
        _queryFailedCallback?.call();
      }

      scheduleUrl = schedule.urls.isNotEmpty ? schedule.urls[0] : null;
    }

    updateFailed = (updatedSchedule == null);
    notifyListeners("updateFailed");

    if (updateFailed) {
      _cancelErrorInFuture();
    }

    print("Refreshing done");
  }

  Future<ScheduleQueryResult?> _readScheduleFromService(
    DateTime start,
    DateTime end,
    CancellationToken token,
  ) async {
    try {
      return await scheduleProvider.getUpdatedSchedule(
        start,
        end,
        token,
      );
    } on OperationCancelledException {
      return null;
    } on ScheduleQueryFailedException {
      return null;
    }
  }

  void _cancelErrorInFuture() {
    _errorResetTimer?.cancel();

    _errorResetTimer = Timer(
      const Duration(seconds: 5),
      () {
        updateFailed = false;
        notifyListeners("updateFailed");
      },
    );
  }

  void ensureUpdateNowTimerRunning() {
    if (_updateNowTimer == null || !_updateNowTimer!.isActive) {
      _updateNowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        notifyListeners("now");
      });
    }
  }

  @override
  void dispose() {
    super.dispose();

    _isDisposed = true;

    _updateNowTimer?.cancel();

    _errorResetTimer?.cancel();
  }

  void setQueryFailedCallback(VoidCallback callback) {
    _queryFailedCallback = callback;
  }
}
