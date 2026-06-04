import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';

class TestCanteenLocationService extends CanteenLocationService {
  CanteenLocation? _configuredLocation;

  TestCanteenLocationService({CanteenLocation? initialLocation})
    : _configuredLocation = initialLocation,
      super(_NoopPreferencesProvider());

  @override
  Future<CanteenLocation> getSelectedLocation() async {
    return _configuredLocation ?? CanteenLocations.defaultLocation;
  }

  @override
  Future<CanteenLocation?> getConfiguredLocation() async {
    return _configuredLocation;
  }

  @override
  Future<void> setSelectedLocation(CanteenLocation location) async {
    _configuredLocation = location;
  }
}

class _NoopPreferencesProvider implements PreferencesProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
