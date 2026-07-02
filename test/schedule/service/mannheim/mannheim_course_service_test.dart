import 'package:dualmate/schedule/service/mannheim/mannheim_course_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MannheimCourseService', () {
    test('parses JSON course list into sorted Mannheim courses', () {
      final service = MannheimCourseService();

      final courses = service.parseCourseList(
        '["WWI23B","TINF23AI2","WWI23A"]',
      );

      expect(courses, hasLength(3));
      expect(courses.map((course) => course.name), [
        'TINF23AI2',
        'WWI23A',
        'WWI23B',
      ]);
      expect(courses[1].scheduleId, 'WWI23A');
      expect(
        courses[1].icalUrl,
        'https://vorlesungsplan.stuvma.de/profiles/WWI23A',
      );
      expect(courses[1].title, isEmpty);
    });

    test(
      'generates safe iCal URLs for profile names with special characters',
      () {
        final url = MannheimCourseService.icalUrlForProfile(
          'IP/International Program & ä',
        );

      expect(
        url,
        'https://vorlesungsplan.stuvma.de/profiles/IP%2FInternational%20Program%20&%20%C3%A4',
      );
      },
    );

    test('accepts only StuV Mannheim profile URLs as Mannheim setup URLs', () {
      expect(
        MannheimCourseService.isMannheimProfileUrl(
          'https://vorlesungsplan.stuvma.de/profiles/WWI23A',
        ),
        isTrue,
      );
      expect(
        MannheimCourseService.isMannheimProfileUrl(
          'https://legacy.invalid/ical.php?uid=7201001',
        ),
        isFalse,
      );
      expect(
        MannheimCourseService.isMannheimProfileUrl(
          'https://vorlesungsplan.stuvma.de/api/calendars',
        ),
        isFalse,
      );
    });

    test('parses empty course lists', () {
      final service = MannheimCourseService();

      expect(service.parseCourseList('[]'), isEmpty);
    });

    test('rejects malformed course lists', () {
      final service = MannheimCourseService();

      expect(
        () => service.parseCourseList('{"courses":["WWI23A"]}'),
        throwsFormatException,
      );
      expect(
        () => service.parseCourseList('["WWI23A",42]'),
        throwsFormatException,
      );
    });
  });
}
