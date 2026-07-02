import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/ui/widgets/select_source_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';

void main() {
  late PreferencesProvider preferencesProvider;
  late _FakeScheduleSourceProvider scheduleSourceProvider;

  setUp(() {
    KiwiContainer().clear();
    preferencesProvider = PreferencesProvider(
      _FakePreferencesAccess(),
      _FakeSecureStorageAccess(),
    );
    scheduleSourceProvider = _FakeScheduleSourceProvider(preferencesProvider);
    KiwiContainer().registerInstance<ScheduleSourceProvider>(
      scheduleSourceProvider,
    );
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  testWidgets(
    'selecting Dualis opens credentials dialog without reusing disposed source dialog context',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(preferencesProvider, scheduleSourceProvider),
      );

      await tester.tap(find.text('Open source dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dualis'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Dualis Login'), findsOneWidget);
      expect(
        find.text(
          'To view the schedule from Dualis you have to log in using your account:',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(0), 'dualis-user');
      await tester.enterText(find.byType(TextField).at(1), 'dualis-pass');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final credentials = await preferencesProvider.loadDualisCredentials();
      expect(credentials.username, 'dualis-user');
      expect(credentials.password, 'dualis-pass');
      expect(scheduleSourceProvider.setupForDualisCalls, 1);
      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.Dualis.index,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting Dualis does not commit schedule source before credentials are accepted',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(preferencesProvider, scheduleSourceProvider),
      );

      await tester.tap(find.text('Open source dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dualis'));
      await tester.pumpAndSettle();

      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.None.index,
      );
      expect(scheduleSourceProvider.setupForDualisCalls, 0);

      await tester.enterText(find.byType(TextField).at(0), 'dualis-user');
      await tester.enterText(find.byType(TextField).at(1), 'dualis-pass');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(scheduleSourceProvider.setupForDualisCalls, 1);
      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.Dualis.index,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting None still closes source dialog and initializes empty source',
    (tester) async {
      await preferencesProvider.setScheduleSourceType(
        ScheduleSourceType.Rapla.index,
      );
      await tester.pumpWidget(
        _wrapWithApp(preferencesProvider, scheduleSourceProvider),
      );

      await tester.tap(find.text('Open source dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('No schedule'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule'), findsNothing);
      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.None.index,
      );
      expect(scheduleSourceProvider.setupScheduleSourceCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _wrapWithApp(
  PreferencesProvider preferencesProvider,
  ScheduleSourceProvider scheduleSourceProvider,
) {
  return MaterialApp(
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                await SelectSourceDialog(
                  preferencesProvider,
                  scheduleSourceProvider,
                ).show(context);
              },
              child: const Text('Open source dialog'),
            ),
          ),
        );
      },
    ),
  );
}

class _FakeScheduleSourceProvider extends ScheduleSourceProvider {
  final PreferencesProvider _preferencesProvider;

  int setupForDualisCalls = 0;
  int setupScheduleSourceCalls = 0;

  _FakeScheduleSourceProvider(this._preferencesProvider)
    : super(
        _preferencesProvider,
        false,
        _FakeScheduleEntryRepository(),
        _FakeScheduleQueryInformationRepository(),
      );

  @override
  Future<void> setupForDualis() async {
    setupForDualisCalls += 1;
    await _preferencesProvider.setScheduleSourceType(
      ScheduleSourceType.Dualis.index,
    );
  }

  @override
  Future<bool> setupScheduleSource() async {
    setupScheduleSourceCalls += 1;
    return true;
  }
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleEntryRepository call: $invocation',
    );
  }
}

class _FakeScheduleQueryInformationRepository
    implements ScheduleQueryInformationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleQueryInformationRepository call: $invocation',
    );
  }
}

class _FakePreferencesAccess extends PreferencesAccess {
  final Map<String, Object?> _store = <String, Object?>{};

  @override
  Future<void> set<T>(String key, T value) async {
    _store[key] = value;
  }

  @override
  Future<T?> get<T>(String key) async {
    return _store[key] as T?;
  }
}

class _FakeSecureStorageAccess extends SecureStorageAccess {
  final Map<String, String?> _store = <String, String?>{};

  @override
  Future<void> set(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> get(String key) async {
    return _store[key];
  }
}
