import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';

class CanteenLocationService {
  final PreferencesProvider _preferencesProvider;

  CanteenLocationService(this._preferencesProvider);

  Future<CanteenLocation?> getConfiguredLocation() async {
    final id = await _preferencesProvider.getSelectedCanteenLocationId();
    if (id == null || id.isEmpty) {
      return null;
    }

    return CanteenLocations.supportedFromId(id);
  }

  Future<CanteenLocation> getSelectedLocation() async {
    return await getConfiguredLocation() ?? CanteenLocations.defaultLocation;
  }

  Future<void> setSelectedLocation(CanteenLocation location) async {
    await _preferencesProvider.setSelectedCanteenLocationId(location.id);
  }

  List<CanteenLocation> supportedLocations() {
    return List<CanteenLocation>.unmodifiable(CanteenLocations.supported);
  }
}
