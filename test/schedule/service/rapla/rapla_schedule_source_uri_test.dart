import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:test/test.dart';

void main() {
  test('buildRequestUri defaults to https and preserves parameters', () {
    var source = RaplaScheduleSource(
      raplaUrl:
          'rapla.example.com/rapla?page=1&user=alice&file=plan&token=xyz',
    );

    var uri = source.buildRequestUri(DateTime(2026, 1, 22));

    expect(uri.scheme, 'https');
    expect(uri.host, 'rapla.example.com');
    expect(uri.path, '/rapla');
    expect(uri.queryParameters['page'], '1');
    expect(uri.queryParameters['user'], 'alice');
    expect(uri.queryParameters['file'], 'plan');
    expect(uri.queryParameters['token'], 'xyz');
    expect(uri.queryParameters['day'], '22');
    expect(uri.queryParameters['month'], '1');
    expect(uri.queryParameters['year'], '2026');
  });

  test('buildRequestUri keeps explicit http scheme', () {
    var source = RaplaScheduleSource(
      raplaUrl: 'http://rapla.example.com/rapla?key=abc',
    );

    var uri = source.buildRequestUri(DateTime(2026, 6, 5));

    expect(uri.scheme, 'http');
    expect(uri.host, 'rapla.example.com');
    expect(uri.queryParameters['key'], 'abc');
    expect(uri.queryParameters['day'], '5');
    expect(uri.queryParameters['month'], '6');
    expect(uri.queryParameters['year'], '2026');
  });

  test('buildRequestUri overwrites existing date parameters', () {
    var source = RaplaScheduleSource(
      raplaUrl:
          'https://rapla.example.com/rapla?key=abc&day=1&month=1&year=2000',
    );

    var uri = source.buildRequestUri(DateTime(2026, 12, 31));

    expect(uri.queryParameters['key'], 'abc');
    expect(uri.queryParameters['day'], '31');
    expect(uri.queryParameters['month'], '12');
    expect(uri.queryParameters['year'], '2026');
  });
}
