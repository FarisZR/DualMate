import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/date_management/business/date_entry_provider.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/date_management/data/date_entry_repository.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/service/date_management_service.dart';
import 'package:dualmate/dualis/service/cache_dualis_service_decorator.dart';
import 'package:dualmate/dualis/service/dualis_scraper.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/service/fake_account_dualis_scraper_decorator.dart';
import 'package:dualmate/native/widget/widget_helper.dart';
import 'package:dualmate/schedule/background/calendar_synchronizer.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:kiwi/kiwi.dart';

bool _isInjected = false;

///
/// This function injects all instances into the KiwiContainer. You can get a
/// singleton instance of a registered type using KiwiContainer().resolve()
///
void injectServices(bool isBackground) {
  if (_isInjected) return;

  KiwiContainer c = KiwiContainer();
  c.registerInstance(PreferencesProvider(
    PreferencesAccess(),
    SecureStorageAccess(),
  ));
  c.registerInstance(DatabaseAccess());
  c.registerInstance(CanteenMealRepository(
    c.resolve(),
  ));
  c.registerInstance(CanteenScraper());
  c.registerInstance(CanteenProvider(
    c.resolve(),
    c.resolve(),
  ));
  c.registerInstance(ScheduleEntryRepository(
    c.resolve(),
  ));
  c.registerInstance(ScheduleFilterRepository(
    c.resolve(),
  ));
  c.registerInstance(ScheduleQueryInformationRepository(
    c.resolve(),
  ));
  c.registerInstance(ScheduleSourceProvider(
    c.resolve(),
    isBackground,
    c.resolve(),
    c.resolve(),
  ));
  c.registerInstance(ScheduleProvider(
    c.resolve(),
    c.resolve(),
    c.resolve(),
    c.resolve(),
    c.resolve(),
  ));
  c.registerInstance<DualisScraper>(
    FakeAccountDualisScraperDecorator(DualisScraper()),
  );
  c.registerInstance<DualisService>(CacheDualisServiceDecorator(
    DualisServiceImpl(
      c.resolve(),
    ),
  ));
  c.registerInstance(DateEntryProvider(
    DateManagementService(),
    DateEntryRepository(c.resolve()),
  ));
  c.registerInstance(RaplaImportantEventsProvider(
    c.resolve(),
  ));
  c.registerInstance(WidgetHelper());
  c.registerInstance(ListDateEntries30d(List<DateEntry>.empty(growable: true)));

  _isInjected = true;
}
