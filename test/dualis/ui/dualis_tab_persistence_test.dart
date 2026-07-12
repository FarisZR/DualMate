import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/ui/pager_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    KiwiContainer().clear();
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  testWidgets(
    'Dualis tab selection is immediate and persisted after the frame',
    (tester) async {
      final preferencesAccess = _TrackingPreferencesAccess();
      KiwiContainer().registerInstance<PreferencesProvider>(
        PreferencesProvider(preferencesAccess, _FakeSecureStorageAccess()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PagerWidget(
            pagesId: 'dualis_pager',
            pages: [
              PageDefinition(
                text: 'Overview',
                icon: const Icon(Icons.dashboard),
                builder: (_) => const Text('overview_content'),
              ),
              PageDefinition(
                text: 'Exams',
                icon: const Icon(Icons.book),
                builder: (_) => const Text('exams_content'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final bottomNavigationBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      bottomNavigationBar.onTap!(1);
      expect(preferencesAccess.writes, isEmpty);

      await tester.pump();
      expect(find.text('exams_content'), findsOneWidget);
      expect(preferencesAccess.writes, hasLength(1));
      expect(preferencesAccess.writes.single.key, 'dualis_pager_active_page');
      expect(preferencesAccess.writes.single.value, 1);

      final switchedBackNavigationBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      switchedBackNavigationBar.onTap!(0);
      expect(preferencesAccess.writes, hasLength(1));

      await tester.pump();
      expect(find.text('overview_content'), findsOneWidget);

      expect(
        preferencesAccess.writes.map((entry) => entry.key),
        everyElement('dualis_pager_active_page'),
      );
      expect(preferencesAccess.writes.map((entry) => entry.value), <Object>[
        1,
        0,
      ]);
    },
  );

  testWidgets('pending tab selection persists when pager is disposed', (
    tester,
  ) async {
    final preferencesAccess = _TrackingPreferencesAccess();
    KiwiContainer().registerInstance<PreferencesProvider>(
      PreferencesProvider(preferencesAccess, _FakeSecureStorageAccess()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PagerWidget(
          pagesId: 'dualis_pager',
          pages: [
            PageDefinition(
              text: 'Overview',
              icon: const Icon(Icons.dashboard),
              builder: (_) => const Text('overview_content'),
            ),
            PageDefinition(
              text: 'Exams',
              icon: const Icon(Icons.book),
              builder: (_) => const Text('exams_content'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).onTap!(
      1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(preferencesAccess.writes, hasLength(1));
    expect(preferencesAccess.writes.single.key, 'dualis_pager_active_page');
    expect(preferencesAccess.writes.single.value, 1);
  });

  testWidgets('rapid tab selections persist only the latest page', (
    tester,
  ) async {
    final preferencesAccess = _TrackingPreferencesAccess();
    KiwiContainer().registerInstance<PreferencesProvider>(
      PreferencesProvider(preferencesAccess, _FakeSecureStorageAccess()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PagerWidget(
          pagesId: 'dualis_pager',
          pages: [
            PageDefinition(
              text: 'Overview',
              icon: const Icon(Icons.dashboard),
              builder: (_) => const Text('overview_content'),
            ),
            PageDefinition(
              text: 'Exams',
              icon: const Icon(Icons.book),
              builder: (_) => const Text('exams_content'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final navigationBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    navigationBar.onTap!(1);
    navigationBar.onTap!(0);
    expect(preferencesAccess.writes, isEmpty);

    await tester.pump();

    expect(preferencesAccess.writes, hasLength(1));
    expect(preferencesAccess.writes.single.key, 'dualis_pager_active_page');
    expect(preferencesAccess.writes.single.value, 0);
  });
}

class _TrackingPreferencesAccess extends PreferencesAccess {
  final List<MapEntry<String, Object>> writes = <MapEntry<String, Object>>[];

  @override
  Future<void> set<T>(String key, T value) async {
    writes.add(MapEntry<String, Object>(key, value as Object));
  }

  @override
  Future<T?> get<T>(String key) async => null;
}

class _FakeSecureStorageAccess extends SecureStorageAccess {
  @override
  Future<void> set(String key, String value) async {}

  @override
  Future<String?> get(String key) async => null;
}
