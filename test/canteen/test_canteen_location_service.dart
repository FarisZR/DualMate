import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';

class TestCanteenLocationService extends CanteenLocationService {
  String? _cachedLocationId;

  TestCanteenLocationService({CanteenLocation? initialLocation})
    : super(_InMemoryPreferencesProvider(initialLocation?.id));

  @override
  Future<String?> getCachedLocationId() async {
    return _cachedLocationId;
  }

  @override
  Future<void> setCachedLocation(CanteenLocation location) async {
    _cachedLocationId = location.id;
  }
}

class _InMemoryPreferencesProvider implements PreferencesProvider {
  String? selectedCanteenLocationId;

  _InMemoryPreferencesProvider(this.selectedCanteenLocationId);

  @override
  Future<String?> getSelectedCanteenLocationId() async {
    return selectedCanteenLocationId;
  }

  @override
  Future<void> setSelectedCanteenLocationId(String id) async {
    selectedCanteenLocationId = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
