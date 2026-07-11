import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/cold_navigation_fixture.dart';

void main() {
  test(
    'cold navigation fixture configures a valid offline schedule source',
    () {
      expect(
        RaplaScheduleSource.isValidUrl(ColdNavigationFixture.scheduleSourceUrl),
        isTrue,
      );
    },
  );
}
