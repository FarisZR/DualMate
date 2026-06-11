import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';

class SelectCanteenLocationViewModel extends OnboardingStepViewModel {
  final CanteenLocationService _locationService;

  CanteenLocation? _selectedLocation;
  CanteenLocation? get selectedLocation => _selectedLocation;

  List<CanteenLocation> get locations => _locationService.supportedLocations();

  @override
  bool get canSkip => false;

  SelectCanteenLocationViewModel(this._locationService) {
    setIsValid(false);
    _loadInitialSelection();
  }

  Future<void> _loadInitialSelection() async {
    final location = await _locationService.getConfiguredLocation();
    _selectedLocation = location;
    setIsValid(location != null);
    notifyIfMounted('selectedLocation');
  }

  void setSelectedLocation(CanteenLocation location) {
    _selectedLocation = location;
    setIsValid(true);
    notifyListeners('selectedLocation');
  }

  @override
  Future<void> save() async {
    final location = _selectedLocation;
    if (location == null) {
      return;
    }

    await _locationService.setSelectedLocation(location);
  }
}
