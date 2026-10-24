import 'package:flutter/foundation.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/service/schedule_prettifier.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/native/widget/widget_helper.dart';
import 'package:dualmate/common/ui/notification_api.dart';

class TimetableCustomizationViewModel extends ChangeNotifier {
  final TimetableRepository repository;
  final ScheduleSourceProvider sourceProvider;
  final ScheduleProvider scheduleProvider;
  final ScheduleEntryRepository entryRepository;
  final ClassReminderController? reminders;
  final WidgetHelper? widgets;
  final NotificationApi? notifications;
  List<TimetableConfiguration> sources = [];
  Map<String, List<String>> modules = {};
  final Map<String, Schedule> _previews = {};
  final CancellationToken _token = CancellationToken();
  bool loading = true;
  bool saving = false;
  bool dirty = false;
  bool loadingSource = false;
  bool loadFailed = false;
  bool _disposed = false;

  TimetableCustomizationViewModel({
    required this.repository,
    required this.sourceProvider,
    required this.scheduleProvider,
    required this.entryRepository,
    this.reminders,
    this.widgets,
    this.notifications,
  });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    loadFailed = false;
    _notify();
    try {
      sources = await repository.load();
      modules = await repository.moduleNames();
      for (final source in sources) {
        modules[source.id] = {
          ...?modules[source.id],
          ...source.exceptions,
        }.toList()..sort();
      }
    } catch (_) {
      loadFailed = true;
    }
    loading = false;
    _notify();
  }

  void toggle(TimetableConfiguration source, String title, bool selected) {
    if (saving || loadingSource) return;
    sources = sources
        .map((s) => s.id == source.id ? s.withModule(title, selected) : s)
        .toList();
    dirty = true;
    _notify();
  }

  void remove(TimetableConfiguration source) {
    if (saving || loadingSource) return;
    sources = sources.where((s) => s.id != source.id).toList();
    _previews.remove(source.id);
    dirty = true;
    _notify();
  }

  Future<void> refreshModules(TimetableConfiguration source) async {
    final remote = await sourceProvider.createSource(source);
    final now = DateTime.now();
    var result = (await remote.querySchedule(
      now.subtract(const Duration(days: 14)),
      now.add(const Duration(days: 90)),
      _token,
    )).schedule;
    if (await repository.preferences.getPrettifySchedule())
      result = SchedulePrettifier().prettifySchedule(result);
    result = result.copyWith(
      entries: result.entries
          .map((e) => e.copyWith(sourceIdentity: source.id))
          .toList(),
    );
    _token.throwIfCancelled();
    _previews[source.id] = result;
    modules[source.id] = {
      ...?modules[source.id],
      ...result.entries.map((e) => e.title),
      ...source.exceptions,
    }.toList()..sort();
    _notify();
  }

  Future<void> put(TimetableConfiguration source, {String? replacingId}) async {
    loadingSource = true;
    _notify();
    try {
      if (sources.any((s) => s.id == source.id && s.id != replacingId))
        throw ArgumentError('duplicate');
      final sameEndpoint = replacingId == source.id;
      if (!sameEndpoint) await refreshModules(source);
      if (replacingId == null) {
        sources = [...sources, source];
      } else {
        sources = sources.map((s) => s.id == replacingId ? source : s).toList();
      }
      dirty = true;
      _notify();
    } finally {
      loadingSource = false;
      _notify();
    }
  }

  Future<void> save() async {
    saving = true;
    _notify();
    try {
      await sourceProvider.saveTimetables(sources);
      for (final preview in _previews.entries) {
        if (sources.any((s) => s.id == preview.key))
          await entryRepository.saveSchedule(preview.value);
      }
      scheduleProvider.invalidateScheduleCache();
      await notifications?.cancelScheduleInformationNotifications();
      await reminders?.waitForSourceChange();
      await reminders?.reconcileUpcoming(waitForCompletion: true);
      await widgets?.requestWidgetRefresh();
      sourceProvider.fireScheduleSourceChanged();
      dirty = false;
    } finally {
      saving = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _token.cancel();
    super.dispose();
  }
}
