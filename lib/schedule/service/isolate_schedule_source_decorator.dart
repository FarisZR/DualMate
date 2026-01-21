import 'dart:async';
import 'dart:isolate';

import 'package:dhbwstudentapp/common/util/cancellation_token.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_query_result.dart';
import 'package:dhbwstudentapp/schedule/service/schedule_source.dart';

///
/// ScheduleSource decorator which executes the [querySchedule] in a separated isolate
///
class IsolateScheduleSourceDecorator extends ScheduleSource {
  final ScheduleSource _scheduleSource;

  late ReceivePort _isolateToMain;
  late SendPort _sendPort;
  bool _isInitialized = false;
  int _requestIdCounter = 0;

  IsolateScheduleSourceDecorator(this._scheduleSource);

  @override
  Future<ScheduleQueryResult> querySchedule(DateTime from, DateTime to,
      [CancellationToken? cancellationToken]) async {
    await _initializeIsolate();
    var token = cancellationToken ?? CancellationToken();
    var requestId = _nextRequestId();
    var responsePort = ReceivePort();

    // Use the cancellation token to send a cancel message.
    // The isolate then uses a new instance to cancel the request
    token.setCancellationCallback(() {
      _sendPort.send({
        "type": "cancel",
        "requestId": requestId,
      });
    });

    _sendPort.send({
      "type": "execute",
      "source": _scheduleSource,
      "from": from,
      "to": to,
      "replyPort": responsePort.sendPort,
      "requestId": requestId,
    });

    try {
      final result = await responsePort.first;
      token.setCancellationCallback(null);

      if (result == null) {
        throw OperationCancelledException();
      } else if (result is ScheduleQueryResult) {
        return result;
      } else {
        throw ScheduleQueryFailedException(result);
      }
    } finally {
      responsePort.close();
    }
  }

  Future<void> _initializeIsolate() async {
    if (_isInitialized) return;

    var isolateToMain = ReceivePort();
    _isolateToMain = isolateToMain;
    await Isolate.spawn(
        scheduleSourceIsolateEntryPoint, isolateToMain.sendPort);
    _sendPort = await _isolateToMain.first;
    _isInitialized = true;
  }

  @override
  bool canQuery() {
    return _scheduleSource.canQuery();
  }

  int _nextRequestId() {
    _requestIdCounter += 1;
    return _requestIdCounter;
  }
}

void scheduleSourceIsolateEntryPoint(SendPort sendPort) async {
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
    replyPort.send("$ex \n$trace");
  }
}
