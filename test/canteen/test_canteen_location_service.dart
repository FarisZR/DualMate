import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';

class TestCanteenLocationService extends CanteenLocationService {
  CanteenLocation _location;

  TestCanteenLocationService({CanteenLocation? initialLocation})
      : _location = initialLocation ?? CanteenLocations.defaultLocation,
        super(_NoopPreferencesProvider());

  @override
  Future<CanteenLocation> getSelectedLocation() async {
    return _location;
  }

  @override
  Future<CanteenLocation?> getConfiguredLocation() async {
    return _location;
  }

  @override
  Future<void> setSelectedLocation(CanteenLocation location) async {
    _location = location;
  }
}

class _NoopPreferencesProvider implements PreferencesProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
