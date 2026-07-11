import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/model/meal_type.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/dualis/service/fake_account_dualis_scraper_decorator.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_information.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeds data that resembles an actively used app without accessing a service.
///
/// The fixture intentionally uses the same repositories as production. The
/// profile run therefore measures cache reads and visible widget construction,
/// not a mock implementation or changing network response.
class ColdNavigationFixture {
  static const String scheduleSourceUrl =
      'https://rapla.dhbw-karlsruhe.de/rapla?'
      'page=calendar&user=strand&file=TINF25B5';
  static const String firstRaplaEventTitle = 'Fixture examination 01';
  static const String firstCanteenMealName = 'Fixture seasonal bowl 01';
  static const String firstScheduleEntryTitle = 'Fixture software engineering';

  final DateTime currentWeekStart;
  final DateTime tallWeekStart;
  final DateTime intermediateWeekStart;
  final DateTime databaseCachedWeekStart;
  final DateTime refreshRequiredWeekStart;

  const ColdNavigationFixture({
    required this.currentWeekStart,
    required this.tallWeekStart,
    required this.intermediateWeekStart,
    required this.databaseCachedWeekStart,
    required this.refreshRequiredWeekStart,
  });

  static Future<ColdNavigationFixture> prepare() async {
    final now = DateTime.now();
    final currentWeekStart = toStartOfDay(toDayOfWeek(now, DateTime.monday));
    final tallWeekStart = toNextWeek(currentWeekStart);
    final intermediateWeekStart = toNextWeek(tallWeekStart);
    final databaseCachedWeekStart = toNextWeek(intermediateWeekStart);
    final refreshRequiredWeekStart = toNextWeek(databaseCachedWeekStart);

    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesProvider.IsFirstStartKey: false,
      PreferencesProvider.ScheduleSourceType: ScheduleSourceType.Rapla.index,
      PreferencesProvider.RaplaUrlKey: scheduleSourceUrl,
      PreferencesProvider.UseDhMineForDates: false,
      PreferencesProvider.DontShowRateNowDialog: true,
      PreferencesProvider.DidShowWidgetHelpDialog: true,
      PreferencesProvider.DualisStoreCredentials: true,
      PreferencesProvider.DualisLastRefreshAt: 0,
      PreferencesProvider.SelectedCanteenLocationId:
          CanteenLocations.karlsruheId,
      PreferencesProvider.CachedCanteenLocationId: CanteenLocations.karlsruheId,
    });

    final database = DatabaseAccess();
    await Future.wait(<Future<void>>[
      _seedSchedule(
        database,
        currentWeekStart: currentWeekStart,
        tallWeekStart: tallWeekStart,
        databaseCachedWeekStart: databaseCachedWeekStart,
        refreshRequiredWeekStart: refreshRequiredWeekStart,
      ),
      _seedCanteen(database, currentWeekStart),
      _seedDualisCredentials(),
    ]);

    return ColdNavigationFixture(
      currentWeekStart: currentWeekStart,
      tallWeekStart: tallWeekStart,
      intermediateWeekStart: intermediateWeekStart,
      databaseCachedWeekStart: databaseCachedWeekStart,
      refreshRequiredWeekStart: refreshRequiredWeekStart,
    );
  }

  static Future<void> _seedSchedule(
    DatabaseAccess database, {
    required DateTime currentWeekStart,
    required DateTime tallWeekStart,
    required DateTime databaseCachedWeekStart,
    required DateTime refreshRequiredWeekStart,
  }) async {
    final entries = ScheduleEntryRepository(database);
    final queryInformation = ScheduleQueryInformationRepository(database);
    await entries.deleteAllScheduleEntries();
    await queryInformation.deleteAllQueryInformation();

    final weekStarts = List<DateTime>.generate(
      18,
      (offset) => currentWeekStart.add(Duration(days: (offset - 1) * 7)),
    ).where((weekStart) => weekStart != refreshRequiredWeekStart);
    final queryTime = DateTime.now();

    for (final weekStart in weekStarts) {
      final isTallWeek = weekStart == tallWeekStart;
      await entries.saveSchedule(
        Schedule.fromList(_buildWeekEntries(weekStart, tall: isTallWeek)),
      );
      await queryInformation.saveScheduleQueryInformation(
        ScheduleQueryInformation(weekStart, toNextWeek(weekStart), queryTime),
      );
    }
  }

  static List<ScheduleEntry> _buildWeekEntries(
    DateTime weekStart, {
    required bool tall,
  }) {
    final entries = <ScheduleEntry>[];
    final days = tall ? 5 : 3;
    final lessonsPerDay = tall ? 4 : 2;

    for (var day = 0; day < days; day++) {
      for (var lesson = 0; lesson < lessonsPerDay; lesson++) {
        final startHour = tall ? 7 + lesson * 3 : 9 + lesson * 2;
        final start = weekStart.add(Duration(days: day, hours: startHour));
        entries.add(
          ScheduleEntry(
            start: start,
            end: start.add(const Duration(hours: 2)),
            title: lesson == 0
                ? firstScheduleEntryTitle
                : 'Fixture course ${day + 1}-${lesson + 1}',
            details: 'Practical lecture with a realistic cached workload',
            professor: lesson.isEven ? 'Prof. Mustermann' : 'Prof. Beispiel',
            room: lesson.isEven ? 'H 101' : 'H 204',
            type: ScheduleEntryType.Class,
          ),
        );
      }
    }

    for (var index = 0; index < 4; index++) {
      final eventStart = weekStart.add(Duration(days: index + 1, hours: 10));
      entries.add(
        ScheduleEntry(
          start: eventStart,
          end: eventStart.add(const Duration(hours: 2)),
          title: tall && index == 0
              ? firstRaplaEventTitle
              : 'Fixture academic event ${weekStart.millisecondsSinceEpoch}-$index',
          details: 'Locally cached important event for Dates profiling.',
          professor: index.isEven ? 'Prof. Beispiel' : '',
          room: 'Campus Karlsruhe',
          type: switch (index % 3) {
            0 => ScheduleEntryType.Exam,
            1 => ScheduleEntryType.SpecialEvent,
            _ => ScheduleEntryType.PublicHoliday,
          },
        ),
      );
    }
    return entries;
  }

  static Future<void> _seedCanteen(
    DatabaseAccess database,
    DateTime currentWeekStart,
  ) async {
    final meals = CanteenMealRepository(database);
    await meals.clearMeals();

    final allMeals = <Meal>[];
    for (var weekOffset = -1; weekOffset <= 1; weekOffset++) {
      final weekStart = currentWeekStart.add(Duration(days: weekOffset * 7));
      for (var day = 0; day < 5; day++) {
        final date = weekStart.add(Duration(days: day));
        final mealCount = 2 + ((day + weekOffset + 5) % 5);
        for (var mealIndex = 0; mealIndex < mealCount; mealIndex++) {
          allMeals.add(
            Meal(
              date: date,
              name: weekOffset == 0 && day == 0 && mealIndex == 0
                  ? firstCanteenMealName
                  : 'Fixture meal ${weekOffset + 2}-${day + 1}-${mealIndex + 1}',
              category: mealIndex.isEven ? 'Menu' : 'Vegetarian',
              price: 2.5 + mealIndex * 0.35,
              notes: const <String>[
                'Allergens and nutrition details are available on request.',
              ],
              mealTypes: <MealType>[
                mealIndex.isEven ? MealType.vegetarian : MealType.healthy,
              ],
            ),
          );
        }
      }
    }
    await meals.saveMeals(allMeals);
  }

  static Future<void> _seedDualisCredentials() async {
    const storage = FlutterSecureStorage();
    await storage.write(
      key: PreferencesProvider.DualisUsername,
      value: FakeAccountDualisScraperDecorator.demoUsername,
    );
    await storage.write(
      key: PreferencesProvider.DualisPassword,
      value: FakeAccountDualisScraperDecorator.demoPassword,
    );
  }
}
