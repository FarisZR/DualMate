import 'dart:convert';

import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:http/http.dart';
import 'package:http_client_helper/http_client_helper.dart' as http;

///
/// Handles cookies and provides a session. Execute your api calls with the
/// provided get and set methods.
///
class Session {
  Map<String, String> cookies = {};

  ///
  /// Execute a GET request and return the result body as string
  ///
  Future<String> get(
    String url, [
    CancellationToken? cancellationToken,
  ]) async {
    var response = await rawGet(url, cancellationToken);

    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException catch (_) {
      return latin1.decode(response.bodyBytes);
    }
  }

  Future<Response> rawGet(
    String url, [
    CancellationToken? cancellationToken,
  ]) async {
    var requestCancellationToken = http.CancellationToken();
    var token = cancellationToken ?? CancellationToken();

    try {
      token.setCancellationCallback(() {
        requestCancellationToken.cancel();
      });

      var requestUri = Uri.parse(url);

      var response = await http.HttpClientHelper.get(
        requestUri,
        cancelToken: requestCancellationToken,
        headers: cookies,
      );

      if (response == null && !requestCancellationToken.isCanceled) {
        throw ServiceRequestFailed("Http request failed!");
      }

      if (response == null) {
        throw OperationCancelledException();
      }

      _updateCookie(response);

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

  ///
  /// Execute a POST request and return the result body as string
  ///
  Future<String> post(
    String url,
    dynamic data, [
    CancellationToken? cancellationToken,
  ]) async {
    var response = await rawPost(url, data, cancellationToken);

    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException catch (_) {
      return latin1.decode(response.bodyBytes);
    }
  }

  Future<Response> rawPost(
    String url,
    dynamic data, [
    CancellationToken? cancellationToken,
  ]) async {
    var requestCancellationToken = http.CancellationToken();
    var token = cancellationToken ?? CancellationToken();

    try {
      token.setCancellationCallback(() {
        requestCancellationToken.cancel();
      });

      var response = await http.HttpClientHelper.post(
        Uri.parse(url),
        body: data,
        headers: cookies,
        cancelToken: requestCancellationToken,
      );

      if (response == null && !requestCancellationToken.isCanceled) {
        throw ServiceRequestFailed("Http request failed!");
      }

      if (response == null) {
        throw OperationCancelledException();
      }

      _updateCookie(response);

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

  void _updateCookie(Response response) {
    String rawCookie = response.headers['set-cookie'] ?? "";
    if (rawCookie.isEmpty) return;
    int index = rawCookie.indexOf(';');

    var cookie = (index == -1) ? rawCookie : rawCookie.substring(0, index);

    cookie = cookie.replaceAll(" ", "");

    cookies['cookie'] = cookie;
  }
}
