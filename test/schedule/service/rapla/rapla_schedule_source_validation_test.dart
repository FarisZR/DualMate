import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the legacy Karlsruhe Rapla calendar URL', () {
    const raplaUrl =
        'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF24B4';

    expect(RaplaScheduleSource.isValidUrl(raplaUrl), isTrue);
  });

  test('accepts the new Karlsruhe Rapla calendar URL', () {
    const raplaUrl =
        'https://rapla.dhbw.de/rapla/calendar?user=ritterbusch%40dhbw-karlsruhe.aa&file=TINF25B2';

    expect(RaplaScheduleSource.isValidUrl(raplaUrl), isTrue);
  });
}
