import 'dart:isolate';

import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/service/canteen_request_failed.dart';
import 'package:dualmate/canteen/service/canteen_parser.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:http/http.dart';
import 'package:http_client_helper/http_client_helper.dart' as http;

typedef CanteenResponseLoader =
    Future<Response?> Function(
      Uri uri,
      http.CancellationToken cancellationToken,
    );

class CanteenScraper {
  final Map<int, String> _weekCache = {};
  final CanteenResponseLoader _loadResponse;

  CanteenScraper({CanteenResponseLoader? loadResponse})
    : _loadResponse = loadResponse ?? _defaultLoadResponse;

  Future<List<DailyMenu>> loadWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async {
    var weekOfYear = _isoWeekNumber(date);

    var cached = _weekCache[weekOfYear];
    if (cached != null) {
      return _parseInIsolate(cached);
    }

    var response = await _makeRequest(_buildUri(weekOfYear), cancellationToken);
    _weekCache[weekOfYear] = response.body;

    return _parseInIsolate(response.body);
  }

  Future<List<DailyMenu>> _parseInIsolate(String html) async {
    try {
      return Isolate.run(() => CanteenParser().parseWeeklyMenu(html));
    } catch (e, st) {
      // Fallback to main thread parse if isolate spawn fails; surface last-good cache upstream.
      print("Canteen parse isolate failed: $e\n$st");
      return CanteenParser().parseWeeklyMenu(html);
    }
  }

  Uri _buildUri(int weekOfYear) {
    return Uri.https(
      "www.sw-ka.de",
      "/de/hochschulgastronomie/speiseplan/mensa_erzberger/",
      {"kw": weekOfYear.toString()},
    );
  }

  int _isoWeekNumber(DateTime date) {
    var thursday = date.add(Duration(days: 4 - date.weekday));
    var firstThursday = DateTime(thursday.year, 1, 4);
    var firstWeekStart = firstThursday.subtract(
      Duration(days: firstThursday.weekday - 1),
    );

    return 1 + (thursday.difference(firstWeekStart).inDays / 7).floor();
  }

  Future<Response> _makeRequest(
    Uri uri,
    CancellationToken? cancellationToken,
  ) async {
    var requestCancellationToken = http.CancellationToken();
    var token = cancellationToken ?? CancellationToken();

    try {
      token.setCancellationCallback(() {
        requestCancellationToken.cancel();
      });

      var response = await _loadResponse(uri, requestCancellationToken);

      if (response == null && !requestCancellationToken.isCanceled) {
        throw CanteenRequestFailed("Http request failed!");
      }

      if (response == null) {
        throw OperationCancelledException();
      }

      return response;
    } on http.OperationCanceledError catch (_) {
      throw OperationCancelledException();
    } on CanteenRequestFailed {
      rethrow;
    } catch (ex, trace) {
      if (requestCancellationToken.isCanceled) {
        throw OperationCancelledException();
      }
      throw CanteenRequestFailed("Http request failed!", ex, trace);
    } finally {
      token.setCancellationCallback(null);
    }
  }

  static Future<Response?> _defaultLoadResponse(
    Uri uri,
    http.CancellationToken cancellationToken,
  ) {
    return http.HttpClientHelper.get(uri, cancelToken: cancellationToken);
  }
}
