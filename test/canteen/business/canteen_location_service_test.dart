import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'invalid configured location id does not fall back as configured',
    () async {
      final service = CanteenLocationService(
        _FakePreferencesProvider('not-supported'),
      );

      expect(await service.getConfiguredLocation(), isNull);
      expect(
        await service.getSelectedLocation(),
        CanteenLocations.defaultLocation,
      );
    },
  );

  test('supported locations include all DHBW.app canteen choices', () {
    final ids = CanteenLocations.supported
        .map((location) => location.id)
        .toSet();

    expect(
      ids,
      containsAll(<String>{
        CanteenLocations.karlsruheId,
        'heilbronn_bildungscampus',
        'mannheim_mensaria_metropol',
        'mannheim_mensaria_wohlgelegen',
        'mannheim_dhbw_eppelheim',
        'mosbach_tannenhof',
        'stuttgart_central',
        'ravensburg',
        'villingen_schwenningen',
        'loerrach',
        'horb',
        'heidenheim',
        'friedrichshafen_fallenbrunnen',
        'karlsruhe_dhbw_app_erzbergerstrasse',
      }),
    );
  });
}

class _FakePreferencesProvider implements PreferencesProvider {
  final String? selectedCanteenLocationId;

  _FakePreferencesProvider(this.selectedCanteenLocationId);

  @override
  Future<String?> getSelectedCanteenLocationId() async {
    return selectedCanteenLocationId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
