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

    test('exposes and removes strict course-code prefixes', () {
      const title = 'WWIA23B2 - Recht';

      expect(CanonicalClassName.courseCodePrefix(title), 'WWIA23B2 -');
      expect(CanonicalClassName.removeCourseCodePrefix(title), 'Recht');
    });

    test('recognizes fallback uppercase course-code prefixes', () {
      const title = 'AB-12 Recht';

      expect(CanonicalClassName.courseCodePrefix(title), 'AB-12');
      expect(CanonicalClassName.fromTitle(title), 'Recht');
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
