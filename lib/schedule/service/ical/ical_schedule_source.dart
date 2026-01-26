import 'dart:convert';

import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/service/parsing/parsing_utils.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/ical/ical_parser.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:http/http.dart';
import 'package:http_client_helper/http_client_helper.dart' as http;

class IcalScheduleSource extends ScheduleSource {
  final IcalParser _icalParser = IcalParser();
  String _url = "";

  void setIcalUrl(String url) {
    _url = url;
  }

  @override
  bool canQuery() {
    return isValidUrl(_url);
  }

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    var response = await _makeRequest(_url, cancellationToken);

    try {
      var body = utf8.decode(response.bodyBytes);
      var schedule = _icalParser.parseIcal(body);

      return ScheduleQueryResult(
        schedule.schedule.trim(from, to),
        schedule.errors,
      );
    } on ParseException catch (_) {
      rethrow;
    } catch (exception, trace) {
      throw ParseException.withInner(exception, trace);
    }
  }

  Future<Response> _makeRequest(
      String url, CancellationToken? cancellationToken) async {
    url = url.replaceAll("webcal://", "https://");

    var requestCancellationToken = http.CancellationToken();
    var token = cancellationToken ?? CancellationToken();

    try {
      token.setCancellationCallback(() {
        requestCancellationToken.cancel();
      });

      var response = await http.HttpClientHelper.get(
        Uri.parse(url),
        cancelToken: requestCancellationToken,
      );

      if (response == null && !requestCancellationToken.isCanceled) {
        throw ServiceRequestFailed("Http request failed!");
      }

      if (response == null) {
        throw OperationCancelledException();
      }

      return response;
    } on http.OperationCanceledError catch (_) {
      throw OperationCancelledException();
    } catch (ex) {
      if (requestCancellationToken.isCanceled) {
        throw OperationCancelledException();
      }
      rethrow;
    } finally {
      token.setCancellationCallback(null);
    }
  }

  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
    } catch (e) {
      return false;
    }

    return true;
  }
}
