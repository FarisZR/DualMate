import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'builds without transient exception before weekly initialization',
    (tester) async {
      final provider = _TrackingScheduleProvider(const <ScheduleEntry>[]);
      final sourceProvider = _FakeScheduleSourceProvider();
      final viewModel = WeeklyScheduleViewModel(
        provider,
        sourceProvider,
        nowProvider: () => DateTime(2026, 2, 10, 10, 0),
      );

      await tester.pumpWidget(_wrapWithApp(viewModel));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
      expect(find.byType(WeeklySchedulePage), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      viewModel.dispose();
    },
  );

  testWidgets(
    'initialization loads cache before deferring first network refresh',
    (tester) async {
      final provider = _TrackingScheduleProvider(<ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'CACHED_ENTRY'),
      ]);
      final sourceProvider = _FakeScheduleSourceProvider();
      final viewModel = WeeklyScheduleViewModel(
        provider,
        sourceProvider,
        nowProvider: () => DateTime(2026, 2, 10, 10, 0),
      );

      await viewModel.initialize();
      await tester.pump();

      expect(provider.cachedRequests, isNotEmpty);
      expect(viewModel.weekSchedule?.entries.single.title, 'CACHED_ENTRY');
      expect(provider.updatedOrigins, isEmpty);

      await tester.pump(const Duration(seconds: 5));
      expect(provider.updatedOrigins, isEmpty);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(
        provider.updatedOrigins,
        contains(ScheduleRefreshOrigin.userBrowsing),
      );

      viewModel.dispose();
    },
  );

  testWidgets('pull to refresh reloads the visible week', (tester) async {
    final provider = _TrackingScheduleProvider(const <ScheduleEntry>[]);
    final sourceProvider = _FakeScheduleSourceProvider();
    final viewModel = WeeklyScheduleViewModel(
      provider,
      sourceProvider,
      nowProvider: () => DateTime(2026, 2, 10, 10, 0),
    );

    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      provider.updatedOrigins,
      contains(ScheduleRefreshOrigin.userBrowsing),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets(
    'resume-triggered background refresh keeps monday lessons visible',
    (tester) async {
      const mondayTitle = 'MONDAY_ANCHOR';
      final entries = <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), mondayTitle),
        _entry(DateTime(2026, 2, 10), 'TUESDAY_ENTRY'),
        _entry(DateTime(2026, 2, 16), 'NEXT_MONDAY'),
      ];
      final provider = _TrackingScheduleProvider(entries);
      final sourceProvider = _FakeScheduleSourceProvider();
      final nowOnTuesday = DateTime(2026, 2, 10, 11, 0);
      final viewModel = WeeklyScheduleViewModel(
        provider,
        sourceProvider,
        nowProvider: () => nowOnTuesday,
      );

      await viewModel.updateSchedule(
        DateTime(2026, 2, 9),
        DateTime(2026, 2, 16),
        force: true,
      );

      await tester.pumpWidget(_wrapWithApp(viewModel));
      await tester.pump();

      expect(find.text(mondayTitle), findsOneWidget);
      expect(viewModel.currentDateStart, DateTime(2026, 2, 9));
      expect(viewModel.currentDateStart.weekday, DateTime.monday);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(viewModel.currentDateStart, DateTime(2026, 2, 9));
      expect(viewModel.currentDateStart.weekday, DateTime.monday);
      expect(find.text(mondayTitle), findsOneWidget);

      expect(
        provider.cachedRequests.any(
          (request) =>
              request.start == DateTime(2026, 2, 10) &&
              request.end == DateTime(2026, 2, 24),
        ),
        isTrue,
      );
      expect(
        provider.updatedOrigins,
        contains(ScheduleRefreshOrigin.foregroundMaintenance),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      viewModel.dispose();
    },
  );

  testWidgets(
    'schedule filter changes apply immediately on source-changed callback',
    (tester) async {
      const hiddenTitle = 'FILTER_HIDE_NOW';
      const keepTitle = 'FILTER_KEEP_NOW';
      final entries = <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), hiddenTitle),
        _entry(DateTime(2026, 2, 10), keepTitle),
      ];
      final provider = _TrackingScheduleProvider(entries);
      final sourceProvider = _FakeScheduleSourceProvider();
      final viewModel = WeeklyScheduleViewModel(
        provider,
        sourceProvider,
        nowProvider: () => DateTime(2026, 2, 10, 10, 0),
      );

      await viewModel.initialize();
      await viewModel.updateSchedule(
        DateTime(2026, 2, 9),
        DateTime(2026, 2, 16),
        force: true,
      );

      await tester.pumpWidget(_wrapWithApp(viewModel));
      await tester.pump();

      expect(find.text(hiddenTitle), findsOneWidget);
      expect(find.text(keepTitle), findsOneWidget);

      provider.setHiddenTitles({hiddenTitle});
      sourceProvider.fireScheduleSourceChanged();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text(hiddenTitle), findsNothing);
      expect(find.text(keepTitle), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      viewModel.dispose();
    },
  );

  testWidgets('shows delayed loading line while refresh is running', (
    tester,
  ) async {
    final provider = _QueuedBlockingTrackingScheduleProvider(
      const <ScheduleEntry>[],
    );
    final sourceProvider = _FakeScheduleSourceProvider();
    final viewModel = WeeklyScheduleViewModel(
      provider,
      sourceProvider,
      nowProvider: () => DateTime(2026, 2, 10, 11, 0),
    );

    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );
    expect(viewModel.isUpdating, isTrue);
    provider.completeNextUpdate();
    await tester.pump(const Duration(milliseconds: 40));

    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('weekly_schedule_loading_line')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 260));

    expect(
      find.byKey(const ValueKey<String>('weekly_schedule_loading_line')),
      findsOneWidget,
    );

    provider.completeNextUpdate();
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.isUpdating, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets(
    'loads an unfetched empty week shortly after navigation settles',
    (tester) async {
      final provider = _QueuedBlockingTrackingScheduleProvider(
        const <ScheduleEntry>[],
      );
      final sourceProvider = _FakeScheduleSourceProvider();
      final viewModel = WeeklyScheduleViewModel(
        provider,
        sourceProvider,
        nowProvider: () => DateTime(2026, 2, 10, 11, 0),
      );

      await viewModel.updateSchedule(
        DateTime(2026, 2, 9),
        DateTime(2026, 2, 16),
        force: true,
      );
      expect(viewModel.isUpdating, isTrue);
      provider.completeNextUpdate();
      await tester.pump(const Duration(milliseconds: 40));
      expect(viewModel.isUpdating, isFalse);

      await tester.pumpWidget(_wrapWithApp(viewModel));
      await tester.pump();

      unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 17)));
      await tester.pump(const Duration(milliseconds: 40));

      expect(
        find.byKey(const ValueKey<String>('weekly_schedule_loading_line')),
        findsNothing,
      );
      expect(provider.updatedOrigins.length, 1);

      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 40));

      expect(
        find.byKey(const ValueKey<String>('weekly_schedule_loading_line')),
        findsOneWidget,
      );
      expect(provider.updatedOrigins.length, 2);

      provider.completeNextUpdate();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      viewModel.dispose();
    },
  );
}

Widget _wrapWithApp(WeeklyScheduleViewModel viewModel) {
  return ChangeNotifierProvider<WeeklyScheduleViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(body: WeeklySchedulePage()),
    ),
  );
}

ScheduleEntry _entry(DateTime day, String title) {
  return ScheduleEntry(
    start: DateTime(day.year, day.month, day.day, 9),
    end: DateTime(day.year, day.month, day.day, 10),
    title: title,
    details: 'Lecture',
    professor: 'Prof',
    room: 'R1',
    type: ScheduleEntryType.Class,
  );
}

class _TrackingScheduleProvider implements ScheduleProvider {
  final List<ScheduleEntry> _entries;
  final List<_RangeRequest> cachedRequests = <_RangeRequest>[];
  final List<ScheduleRefreshOrigin> updatedOrigins = <ScheduleRefreshOrigin>[];
  Set<String> _hiddenTitles = <String>{};

  _TrackingScheduleProvider(this._entries);

  void setHiddenTitles(Set<String> hiddenTitles) {
    _hiddenTitles = hiddenTitles;
  }

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    cachedRequests.add(_RangeRequest(start, end));
    return _trim(start, end);
  }

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    updatedOrigins.add(origin);
    return ScheduleQueryResult(_trim(start, end), const []);
  }

  @override
  Future<DateTime?> getLastQueryTimeForWindow(
    DateTime start,
    DateTime end,
  ) async {
    return null;
  }

  Schedule _trim(DateTime start, DateTime end) {
    final entries = _entries
        .where((entry) {
          return start.isBefore(entry.end) && end.isAfter(entry.start);
        })
        .where((entry) => !_hiddenTitles.contains(entry.title))
        .toList();
    return Schedule.fromList(entries);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _QueuedBlockingTrackingScheduleProvider
    extends _TrackingScheduleProvider {
  final List<Completer<ScheduleQueryResult>> _pendingUpdates =
      <Completer<ScheduleQueryResult>>[];

  _QueuedBlockingTrackingScheduleProvider(super.entries);

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) {
    updatedOrigins.add(origin);
    final completer = Completer<ScheduleQueryResult>();
    _pendingUpdates.add(completer);
    return completer.future;
  }

  void completeNextUpdate() {
    if (_pendingUpdates.isEmpty) {
      return;
    }
    final completer = _pendingUpdates.removeAt(0);
    if (completer.isCompleted) {
      return;
    }
    completer.complete(ScheduleQueryResult(Schedule(), const []));
  }
}

class _RangeRequest {
  final DateTime start;
  final DateTime end;

  _RangeRequest(this.start, this.end);
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source = _FakeScheduleSource();
  final List<OnDidChangeScheduleSource> _callbacks =
      <OnDidChangeScheduleSource>[];

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  bool didSetupCorrectly() => true;

  @override
  void addDidChangeScheduleSourceCallback(OnDidChangeScheduleSource callback) {
    _callbacks.add(callback);
  }

  @override
  void removeDidChangeScheduleSourceCallback(
    OnDidChangeScheduleSource callback,
  ) {
    _callbacks.remove(callback);
  }

  void fireScheduleSourceChanged() {
    for (final callback in List.of(_callbacks)) {
      callback(_source, true);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleSourceProvider call: $invocation',
    );
  }
}

class _FakeScheduleSource implements ScheduleSource {
  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(Schedule(), const []);
  }
}
