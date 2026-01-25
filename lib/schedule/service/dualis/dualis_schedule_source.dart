import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/service/dualis_scraper.dart';
import 'package:dualmate/dualis/service/parsing/parsing_utils.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class DualisScheduleSource extends ScheduleSource {
  final DualisScraper _dualisScraper;

  DualisScheduleSource(this._dualisScraper);

  @override
  Future<ScheduleQueryResult> querySchedule(DateTime from, DateTime to,
      [CancellationToken? cancellationToken]) async {
    var token = cancellationToken ?? CancellationToken();
    DateTime current = toStartOfMonth(from);

    var schedule = Schedule();
    var allErrors = <ParseError>[];

    if (!_dualisScraper.isLoggedIn()) {
      await _dualisScraper.loginWithPreviousCredentials(token);
    }

    while (to.isAfter(current) && !token.isCancelled()) {
      try {
        var monthSchedule = await _dualisScraper.loadMonthlySchedule(
            current, token);

        schedule.merge(monthSchedule);
      } on OperationCancelledException {
        rethrow;
      } on ParseException catch (ex, trace) {
        allErrors.add(ParseError(ex, trace));
      } catch (e, trace) {
        print(trace);
        throw ScheduleQueryFailedException(e, trace);
      }

      current = toNextMonth(current);
    }

    if (token.isCancelled()) throw OperationCancelledException();

    schedule = schedule.trim(from, to);

    return ScheduleQueryResult(schedule, allErrors);
  }

  Future<void> setLoginCredentials(Credentials credentials) async {
    _dualisScraper.setLoginCredentials(
      credentials.username,
      credentials.password,
    );
  }

  @override
  bool canQuery() {
    return _dualisScraper.isLoggedIn();
  }
}
