import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/schedule_filter_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    KiwiContainer().clear();
    FilterViewModel.resetCachedStateForTesting();
    KiwiContainer().registerInstance<ScheduleEntryRepository>(
      _FakeScheduleEntryRepository(),
    );
    KiwiContainer().registerInstance<ScheduleFilterRepository>(
      _FakeScheduleFilterRepository(),
    );
  });

  tearDown(() {
    KiwiContainer().clear();
    FilterViewModel.resetCachedStateForTesting();
  });

  testWidgets('hiding a class with reminders asks whether to remove them', (
    tester,
  ) async {
    final reminders = _FakeReminderController({'Class A'});
    await tester.pumpWidget(_app(reminders));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications), findsOneWidget);
    await tester.tap(find.text('Class A'));
    await tester.pumpAndSettle();

    expect(find.text('Hide Class A?'), findsOneWidget);
    expect(find.text('Keep reminders'), findsOneWidget);
    expect(find.text('Hide and remove reminders'), findsOneWidget);

    await tester.tap(find.text('Keep reminders'));
    await tester.pumpAndSettle();

    expect(reminders.removedTitles, isEmpty);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
  });

  testWidgets('hide and remove deletes reminders before hiding the class', (
    tester,
  ) async {
    final reminders = _FakeReminderController({'Class A'});
    await tester.pumpWidget(_app(reminders));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide and remove reminders'));
    await tester.pumpAndSettle();

    expect(reminders.removedTitles, ['Class A']);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    expect(find.byIcon(Icons.notifications), findsNothing);
  });

  testWidgets('cancelling the popup leaves the class displayed', (
    tester,
  ) async {
    final reminders = _FakeReminderController({'Class A'});
    await tester.pumpWidget(_app(reminders));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
    expect(reminders.removedTitles, isEmpty);
  });

  testWidgets('failed reminder removal keeps the class displayed', (
    tester,
  ) async {
    final reminders = _FakeReminderController({'Class A'}, failRemoval: true);
    await tester.pumpWidget(_app(reminders));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide and remove reminders'));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
    expect(find.text('Could not save filters'), findsOneWidget);
  });

  testWidgets('back navigation waits for every in-flight reminder removal', (
    tester,
  ) async {
    final classARemoval = Completer<void>();
    final classBRemoval = Completer<void>();
    final filterRepo = _CapturingFilterRepository();
    KiwiContainer().clear();
    FilterViewModel.resetCachedStateForTesting();
    KiwiContainer().registerInstance<ScheduleEntryRepository>(
      _NamedScheduleEntryRepository(['Class A', 'Class B']),
    );
    KiwiContainer().registerInstance<ScheduleFilterRepository>(filterRepo);

    final reminders = _MultiSlowReminderController({
      'Class A': classARemoval,
      'Class B': classBRemoval,
    });
    await tester.pumpWidget(_app(reminders));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide and remove reminders'));
    await tester.pump();

    await tester.tap(find.text('Class B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide and remove reminders'));
    await tester.pump();

    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.maybePop();
    await tester.pump();

    classBRemoval.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byType(ScheduleFilterPage),
      findsOneWidget,
      reason: 'The earlier Class A removal is still in flight.',
    );
    expect(filterRepo.savedHiddenNames, isEmpty);

    classARemoval.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleFilterPage), findsNothing);
    expect(filterRepo.savedHiddenNames, containsAll(['Class A', 'Class B']));
  });

  testWidgets(
    'back navigation during slow reminder removal waits and persists hidden class',
    (tester) async {
      final saveCompleter = Completer<void>();
      final filterRepo = _CapturingFilterRepository();
      KiwiContainer().clear();
      FilterViewModel.resetCachedStateForTesting();
      KiwiContainer().registerInstance<ScheduleEntryRepository>(
        _FakeScheduleEntryRepository(),
      );
      KiwiContainer().registerInstance<ScheduleFilterRepository>(filterRepo);

      final reminders = _SlowReminderController({
        'Class A',
      }, removalCompleter: saveCompleter);
      await tester.pumpWidget(_app(reminders));
      await tester.pumpAndSettle();

      // Tap class to trigger hide dialog.
      await tester.tap(find.text('Class A'));
      await tester.pumpAndSettle();

      // Choose "Hide and remove reminders" — removal is now pending.
      await tester.tap(find.text('Hide and remove reminders'));
      await tester.pump();

      // Simulate back navigation before removal finishes.
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pump();

      // Page must not have popped yet.
      expect(find.byType(ScheduleFilterPage), findsOneWidget);

      // Complete the removal.
      saveCompleter.complete();
      await tester.pumpAndSettle();

      // Now the page should have popped and the hidden name saved.
      expect(find.byType(ScheduleFilterPage), findsNothing);
      expect(filterRepo.savedHiddenNames, contains('Class A'));
    },
  );
}

Widget _app(ClassReminderController reminders) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('de')],
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ScheduleFilterPage(reminderController: reminders),
  );
}

class _FakeReminderController extends ChangeNotifier
    implements ClassReminderController {
  final Set<String> activeTitles;
  final bool failRemoval;
  final List<String> removedTitles = [];

  _FakeReminderController(this.activeTitles, {this.failRemoval = false});

  @override
  bool hasReminderForTitle(String title) => activeTitles.contains(title);

  @override
  Future<void> removeRemindersForTitle(String title) async {
    if (failRemoval) throw StateError('remove failed');
    removedTitles.add(title);
    activeTitles.remove(title);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reminder controller whose removal waits on [removalCompleter].
class _SlowReminderController extends ChangeNotifier
    implements ClassReminderController {
  final Set<String> activeTitles;
  final Completer<void> removalCompleter;

  _SlowReminderController(this.activeTitles, {required this.removalCompleter});

  @override
  bool hasReminderForTitle(String title) => activeTitles.contains(title);

  @override
  Future<void> removeRemindersForTitle(String title) async {
    await removalCompleter.future;
    activeTitles.remove(title);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MultiSlowReminderController extends ChangeNotifier
    implements ClassReminderController {
  final Map<String, Completer<void>> removals;

  _MultiSlowReminderController(this.removals);

  @override
  bool hasReminderForTitle(String title) => removals.containsKey(title);

  @override
  Future<void> removeRemindersForTitle(String title) async {
    await removals[title]!.future;
    removals.remove(title);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NamedScheduleEntryRepository implements ScheduleEntryRepository {
  final List<String> names;

  _NamedScheduleEntryRepository(this.names);

  @override
  Future<List<String>> queryAllNamesOfScheduleEntries() async => names;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call: $invocation');
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  @override
  Future<List<String>> queryAllNamesOfScheduleEntries() async => ['Class A'];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call: $invocation');
}

class _FakeScheduleFilterRepository implements ScheduleFilterRepository {
  @override
  Future<List<String>> queryAllHiddenNames() async => const [];

  @override
  Future<void> saveAllHiddenNames(List<String> hiddenNames) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call: $invocation');
}

class _CapturingFilterRepository implements ScheduleFilterRepository {
  List<String> savedHiddenNames = [];

  @override
  Future<List<String>> queryAllHiddenNames() async => const [];

  @override
  Future<void> saveAllHiddenNames(List<String> hiddenNames) async {
    savedHiddenNames = List.from(hiddenNames);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected call: $invocation');
}
