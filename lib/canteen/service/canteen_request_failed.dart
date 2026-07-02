import 'package:dualmate/common/logging/diagnostic_exception_filter.dart';

class CanteenRequestFailed
    implements
        Exception,
        ExpectedExternalFailure,
        DiagnosticExceptionWithCause {
  final String message;
  final Object? cause;
  final StackTrace? trace;

  CanteenRequestFailed(this.message, [this.cause, this.trace]);

  @override
  Object? get diagnosticCause => cause;

  @override
  String toString() => message;
}
