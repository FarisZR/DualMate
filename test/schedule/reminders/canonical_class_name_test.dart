import 'package:dualmate/schedule/reminders/canonical_class_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanonicalClassName', () {
    test(
      'normalizes online prefixes and suffixes independently of display',
      () {
        expect(CanonicalClassName.fromTitle('Online - Recht'), 'Recht');
        expect(CanonicalClassName.fromTitle('Recht online'), 'Recht');
        expect(CanonicalClassName.fromTitle('(ONLINE) - Recht'), 'Recht');
      },
    );

    test('removes recognized course-code prefixes', () {
      expect(
        CanonicalClassName.fromTitle('T3MB9025 Fluidmechanik'),
        'Fluidmechanik',
      );
      expect(CanonicalClassName.fromTitle('W3WI_SE411 Recht'), 'Recht');
      expect(CanonicalClassName.fromTitle('ABC12 - Seminar'), 'Seminar');
    });

    test('preserves meaningful title distinctions', () {
      expect(CanonicalClassName.fromTitle('Recht II'), 'Recht II');
      expect(CanonicalClassName.fromTitle('Recht'), isNot('Recht II'));
    });

    test(
      'normalizes whitespace but keeps exact case-sensitive wording stable',
      () {
        expect(CanonicalClassName.fromTitle('  Recht   II  '), 'Recht II');
        expect(
          CanonicalClassName.fromTitle('Wirtschaftsrecht'),
          isNot('Recht'),
        );
      },
    );
  });
}
