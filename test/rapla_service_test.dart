import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:test/test.dart';

void main() {
  test('debugging', () async {
    const raplaUrl =
        "https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF24B4";

    expect(RaplaScheduleSource.isValidUrl(raplaUrl), isTrue);
  });
}
