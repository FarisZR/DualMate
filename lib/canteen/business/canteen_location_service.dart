import 'dart:async';

import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';

class CanteenLocationService {
  final PreferencesProvider _preferencesProvider;
  final StreamController<CanteenLocation> _selectedLocationChanges =
      StreamController<CanteenLocation>.broadcast();

  CanteenLocationService(this._preferencesProvider);

  Stream<CanteenLocation> get selectedLocationChanges =>
      _selectedLocationChanges.stream;

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
    _notifySelectedLocationChanged(location);
  }

  void _notifySelectedLocationChanged(CanteenLocation location) {
    if (_selectedLocationChanges.isClosed) return;
    _selectedLocationChanges.add(location);
  }

  Future<String?> getCachedLocationId() async {
    return await _preferencesProvider.getCachedCanteenLocationId();
  }

  Future<void> setCachedLocation(CanteenLocation location) async {
    await _preferencesProvider.setCachedCanteenLocationId(location.id);
  }

  List<CanteenLocation> supportedLocations() {
    return List<CanteenLocation>.unmodifiable(CanteenLocations.supported);
  }
}
