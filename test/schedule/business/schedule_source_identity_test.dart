import 'package:dualmate/schedule/business/schedule_source_identity.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rapla identity ignores navigation and date parameters', () {
    const first =
        'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B4&day=1&month=7&year=2026&next=%3E%3E';
    const second =
        'https://rapla.dhbw-karlsruhe.de/rapla?year=2027&file=TINF25B4&prev=%3C%3C&user=eisenbiegler&page=calendar&month=2&day=18';

    expect(
      ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, first),
      ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, second),
    );
  });

  test('Rapla identity normalizes omitted scheme and host casing', () {
    const first =
        'rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B4';
    const second =
        'https://RAPLA.DHBW-KARLSRUHE.DE/rapla?file=TINF25B4&user=eisenbiegler&page=calendar';

    expect(
      ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, first),
      ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, second),
    );
  });

  test('Rapla identity changes when the actual calendar changes', () {
    const first =
        'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B4';
    const second =
        'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B5';

    expect(
      ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, first),
      isNot(ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, second)),
    );
  });

  test('Rapla identity with repeated key differs from either single-value URL', () {
    const repeated =
        'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B4&file=TINF25B5';
    const singleFirst =
        'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B4';
    // Old Map.fromEntries collapsed repeated keys to the last sorted value
    // (TINF25B5). The repeated identity must differ from that value too.
    const singleLast =
        'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B5';

    final repeatedId = ScheduleSourceIdentity.create(
      ScheduleSourceType.Rapla,
      repeated,
    );
    expect(
      repeatedId,
      isNot(
        ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, singleFirst),
      ),
    );
    expect(
      repeatedId,
      isNot(
        ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, singleLast),
      ),
    );
  });

  test(
    'Rapla identity with repeated key is the same regardless of value order',
    () {
      const orderA =
          'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B4&file=TINF25B5';
      const orderB =
          'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B5&file=TINF25B4';

      expect(
        ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, orderA),
        ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, orderB),
      );
    },
  );
}
