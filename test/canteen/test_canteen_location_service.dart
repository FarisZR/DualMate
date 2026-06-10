import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';

class TestCanteenLocationService extends CanteenLocationService {
  CanteenLocation? _configuredLocation;
  String? _cachedLocationId;

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

  @override
  Future<String?> getCachedLocationId() async {
    return _cachedLocationId;
  }

  @override
  Future<void> setCachedLocation(CanteenLocation location) async {
    _cachedLocationId = location.id;
  }
}

class _NoopPreferencesProvider implements PreferencesProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
