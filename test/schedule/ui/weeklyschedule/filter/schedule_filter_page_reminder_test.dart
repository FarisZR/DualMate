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
