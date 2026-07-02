import 'dart:collection';

import 'package:dualmate/common/util/cancellation_token.dart';

abstract interface class ExpectedExternalFailure implements Exception {}

abstract interface class DiagnosticExceptionWithCause implements Exception {
  Object? get diagnosticCause;
}

bool shouldSuppressDiagnosticsException(Object error) {
  return _shouldSuppressDiagnosticsException(error, LinkedHashSet.identity());
}

bool _shouldSuppressDiagnosticsException(Object error, Set<Object> seen) {
  if (!seen.add(error)) {
    return false;
  }

  if (error is OperationCancelledException) {
    return true;
  }

  if (error is ExpectedExternalFailure) {
    return true;
  }

  if (error is DiagnosticExceptionWithCause) {
    final cause = error.diagnosticCause;
    if (cause == null) {
      return false;
    }
    return _shouldSuppressDiagnosticsException(cause, seen);
  }

  return false;
}
