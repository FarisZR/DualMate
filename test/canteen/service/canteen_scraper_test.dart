import 'package:dualmate/canteen/service/canteen_request_failed.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts null HTTP responses into CanteenRequestFailed', () async {
    final scraper = CanteenScraper(loadResponse: (_, __) async => null);

    await expectLater(
      scraper.loadWeek(DateTime(2026, 2, 9)),
      throwsA(
        isA<CanteenRequestFailed>()
            .having((error) => error.cause, 'cause', isNull)
            .having(
              (error) => error.toString(),
              'message',
              'Http request failed!',
            ),
      ),
    );
  });

  test('wraps HTTP loader failures as CanteenRequestFailed', () async {
    final cause = StateError('socket closed');
    final scraper = CanteenScraper(
      loadResponse: (_, __) async {
        throw cause;
      },
    );

    await expectLater(
      scraper.loadWeek(DateTime(2026, 2, 9)),
      throwsA(
        isA<CanteenRequestFailed>()
            .having((error) => error.cause, 'cause', same(cause))
            .having(
              (error) => error.toString(),
              'message',
              contains('Http request failed!: Bad state: socket closed'),
            ),
      ),
    );
  });
}
