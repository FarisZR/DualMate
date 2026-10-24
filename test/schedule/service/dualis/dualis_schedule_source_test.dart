import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/service/dualis_scraper.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/service/combined_schedule_source.dart';
import 'package:dualmate/schedule/service/dualis/dualis_schedule_source.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a cold Dualis account can query inside a combined timetable', () async {
    final scraper = _Scraper();
    final source = DualisScheduleSource(scraper);
    expect(source.canQuery(), isFalse);
    await source.setLoginCredentials(Credentials('student', 'secret'));
    final combined = CombinedScheduleSource({'dualis:student': source});
    expect(combined.canQuery(), isTrue);
    await combined.querySchedule(DateTime(2026, 10), DateTime(2026, 11));
    expect(scraper.logins, 1);
    expect(scraper.queries, 1);
  });

  test(
    'failed login does not query or return an empty successful schedule',
    () async {
      final scraper = _Scraper(result: LoginResult.LoginFailed);
      final source = DualisScheduleSource(scraper);
      await source.setLoginCredentials(Credentials('student', 'wrong'));
      await expectLater(
        source.querySchedule(DateTime(2026, 10), DateTime(2026, 11)),
        throwsA(isA<ScheduleQueryFailedException>()),
      );
      expect(scraper.queries, 0);
    },
  );
}

class _Scraper implements DualisScraper {
  final LoginResult result;
  bool loggedIn = false;
  int logins = 0;
  int queries = 0;
  _Scraper({this.result = LoginResult.LoggedIn});
  @override
  bool isLoggedIn() => loggedIn;
  @override
  void setLoginCredentials(String username, String password) {}
  @override
  Future<LoginResult> loginWithPreviousCredentials(
    CancellationToken? token,
  ) async {
    logins++;
    loggedIn = result == LoginResult.LoggedIn;
    return result;
  }

  @override
  Future<Schedule> loadMonthlySchedule(
    DateTime month,
    CancellationToken? token,
  ) async {
    queries++;
    return Schedule();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
