import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'package:dualmate/common/logging/diagnostic_exception_filter.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/rapla_tls_override.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

///
/// ScheduleSource decorator which executes the [querySchedule] in a separated isolate
///
class IsolateScheduleSourceDecorator extends ScheduleSource {
  final ScheduleSource _scheduleSource;

  IsolateScheduleSourceDecorator(this._scheduleSource);

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    final token = cancellationToken ?? CancellationToken();
    token.throwIfCancelled();
    final handshake = ReceivePort();
    final responsePort = ReceivePort();
    Isolate? worker;
    try {
      // Scope the parser worker to this request. Replacing sources or previewing
      // extra classes must not leave idle isolates alive for the app's lifetime.
      worker = await Isolate.spawn(
        scheduleSourceIsolateEntryPoint,
        handshake.sendPort,
      );
      final sendPort = await handshake.first as SendPort;
      token.throwIfCancelled();
      token.setCancellationCallback(() => responsePort.sendPort.send(null));
      sendPort.send({
        "type": "execute",
        "source": _scheduleSource,
        "from": from,
        "to": to,
        "replyPort": responsePort.sendPort,
      });
      final result = await responsePort.first;

      if (result == null) {
        throw OperationCancelledException();
      } else if (result is ScheduleQueryResult) {
        return result;
      } else if (_isExpectedExternalFailureResult(result)) {
        throw _scheduleQueryFailedFromExpectedExternalFailureResult(result);
      } else {
        throw ScheduleQueryFailedException(result);
      }
    } finally {
      token.setCancellationCallback(null);
      worker?.kill(priority: Isolate.immediate);
      handshake.close();
      responsePort.close();
    }
  }

  @override
  bool canQuery() {
    return _scheduleSource.canQuery();
  }
}

void scheduleSourceIsolateEntryPoint(SendPort sendPort) async {
  HttpOverrides.global = RaplaHttpOverrides();

  // Using the given send port, send back a send port for two way communication
  var port = ReceivePort();
  sendPort.send(port.sendPort);

  final tokenMap = <int, CancellationToken>{};

  await for (var message in port) {
    if (message["type"] == "execute") {
      var token = CancellationToken();
      var requestId = message["requestId"] as int?;
      if (requestId != null) {
        tokenMap[requestId] = token;
      }
      executeQueryScheduleMessage(message, token).whenComplete(() {
        if (requestId != null) {
          tokenMap.remove(requestId);
        }
      });
    } else if (message["type"] == "cancel") {
      var requestId = message["requestId"] as int?;
      if (requestId != null) {
        tokenMap[requestId]?.cancel();
      }
    }
  }
}

Future<void> executeQueryScheduleMessage(
  Map<String, dynamic> map,
  CancellationToken token,
) async {
  try {
    ScheduleSource source = map["source"];
    DateTime from = map["from"];
    DateTime to = map["to"];
    SendPort replyPort = map["replyPort"];

    var result = await source.querySchedule(from, to, token);

    replyPort.send(result);
  } on OperationCancelledException catch (_) {
    SendPort replyPort = map["replyPort"];
    replyPort.send(null);
  } catch (ex, trace) {
    SendPort replyPort = map["replyPort"];
    if (shouldSuppressDiagnosticsException(ex)) {
      replyPort.send({
        "type": "expectedExternalFailure",
        "message": ex.toString(),
        "trace": trace.toString(),
      });
      return;
    }
    replyPort.send("$ex \n$trace");
  }
}

bool _isExpectedExternalFailureResult(Object? result) {
  if (result is! Map) {
    return false;
  }
  return result["type"] == "expectedExternalFailure";
}

ScheduleQueryFailedException
_scheduleQueryFailedFromExpectedExternalFailureResult(Object result) {
  final map = result as Map;
  final message = map["message"]?.toString() ?? "Schedule request failed";
  final traceValue = map["trace"]?.toString();
  return ScheduleQueryFailedException(
    ServiceRequestFailed(message),
    traceValue == null ? null : StackTrace.fromString(traceValue),
  );
}
