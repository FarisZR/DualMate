import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/appstart/debug_startup_overrides.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesProvider preferencesProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    preferencesProvider =
        PreferencesProvider(PreferencesAccess(), SecureStorageAccess());
  });

  group('isActive', () {
    test('empty overrides are inactive', () {
      expect(const DebugStartupOverrides().isActive, isFalse);
    });

    test('skip onboarding makes overrides active', () {
      expect(const DebugStartupOverrides(skipOnboarding: true).isActive, isTrue);
    });

    test('a rapla url makes overrides active', () {
      expect(
        const DebugStartupOverrides(raplaUrl: 'https://rapla.example').isActive,
        isTrue,
      );
    });
  });

  group('effectiveScheduleSource', () {
    test('explicit source wins over inferred url source', () {
      final overrides = DebugStartupOverrides(
        scheduleSource: ScheduleSourceType.Dualis,
        raplaUrl: 'https://rapla.example',
      );
      expect(overrides.effectiveScheduleSource, ScheduleSourceType.Dualis);
    });

    test('rapla url infers rapla source', () {
      const overrides = DebugStartupOverrides(raplaUrl: 'https://rapla.example');
      expect(overrides.effectiveScheduleSource, ScheduleSourceType.Rapla);
    });

    test('ical url infers ical source', () {
      const overrides = DebugStartupOverrides(icalUrl: 'https://ical.example');
      expect(overrides.effectiveScheduleSource, ScheduleSourceType.Ical);
    });

    test('mannheim id infers mannheim source', () {
      const overrides = DebugStartupOverrides(mannheimId: 'abc123');
      expect(overrides.effectiveScheduleSource, ScheduleSourceType.Mannheim);
    });

    test('no source clues returns null', () {
      const overrides = DebugStartupOverrides(skipOnboarding: true);
      expect(overrides.effectiveScheduleSource, isNull);
    });
  });

  group('apply', () {
    test('marks first start as completed when skipOnboarding is set', () async {
      const overrides = DebugStartupOverrides(skipOnboarding: true);

      await overrides.apply(preferencesProvider);

      expect(await preferencesProvider.isFirstStart(), isFalse);
    });

    test('does not touch first start when skipOnboarding is false', () async {
      const overrides = DebugStartupOverrides(raplaUrl: 'https://rapla.example');

      await overrides.apply(preferencesProvider);

      expect(await preferencesProvider.isFirstStart(), isTrue);
    });

    test('persists rapla url and infers rapla source type', () async {
      const overrides = DebugStartupOverrides(raplaUrl: 'https://rapla.example');

      await overrides.apply(preferencesProvider);

      expect(await preferencesProvider.getRaplaUrl(), 'https://rapla.example');
      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.Rapla.index,
      );
    });

    test('persists ical url and infers ical source type', () async {
      const overrides = DebugStartupOverrides(icalUrl: 'https://ical.example');

      await overrides.apply(preferencesProvider);

      expect(await preferencesProvider.getIcalUrl(), 'https://ical.example');
      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.Ical.index,
      );
    });

    test('persists mannheim id and infers mannheim source type', () async {
      const overrides = DebugStartupOverrides(mannheimId: 'course-42');

      await overrides.apply(preferencesProvider);

      expect(await preferencesProvider.getMannheimScheduleId(), 'course-42');
      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.Mannheim.index,
      );
    });

    test('explicit schedule source overrides inferred url source', () async {
      const overrides = DebugStartupOverrides(
        raplaUrl: 'https://rapla.example',
        scheduleSource: ScheduleSourceType.None,
      );

      await overrides.apply(preferencesProvider);

      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.None.index,
      );
    });

    test('persists supported canteen location id', () async {
      const overrides = DebugStartupOverrides(
        canteenLocationId: CanteenLocations.karlsruheId,
      );

      await overrides.apply(preferencesProvider);

      expect(
        await preferencesProvider.getSelectedCanteenLocationId(),
        CanteenLocations.karlsruheId,
      );
    });

    test('ignores unknown canteen location id', () async {
      const overrides = DebugStartupOverrides(
        canteenLocationId: 'does_not_exist',
      );

      await overrides.apply(preferencesProvider);

      expect(await preferencesProvider.getSelectedCanteenLocationId(), isNull);
    });

    test('applies a full setup combination', () async {
      const overrides = DebugStartupOverrides(
        skipOnboarding: true,
        raplaUrl: 'https://rapla.example',
        canteenLocationId: CanteenLocations.karlsruheId,
      );

      await overrides.apply(preferencesProvider);

      expect(await preferencesProvider.isFirstStart(), isFalse);
      expect(await preferencesProvider.getRaplaUrl(), 'https://rapla.example');
      expect(
        await preferencesProvider.getScheduleSourceType(),
        ScheduleSourceType.Rapla.index,
      );
      expect(
        await preferencesProvider.getSelectedCanteenLocationId(),
        CanteenLocations.karlsruheId,
      );
    });

    test('empty overrides change nothing', () async {
      const overrides = DebugStartupOverrides();

      await overrides.apply(preferencesProvider);

      expect(await preferencesProvider.isFirstStart(), isTrue);
      expect(await preferencesProvider.getRaplaUrl(), '');
      expect(await preferencesProvider.getSelectedCanteenLocationId(), isNull);
    });
  });

  group('fromEnvironment', () {
    test('returns inactive overrides when no defines are set', () {
      final overrides = DebugStartupOverrides.fromEnvironment();

      expect(overrides.isActive, isFalse);
      expect(overrides.skipOnboarding, isFalse);
      expect(overrides.scheduleSource, isNull);
      expect(overrides.raplaUrl, isNull);
      expect(overrides.canteenLocationId, isNull);
    });
  });
}
