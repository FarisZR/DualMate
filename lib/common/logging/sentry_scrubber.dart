// ignore_for_file: deprecated_member_use

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

const String sentryRedactedValue = '[redacted]';

const Set<String> _sensitiveTerms = <String>{
  'password',
  'username',
  'user',
  'email',
  'token',
  'cookie',
  'auth',
  'authorization',
  'rapla',
  'ical',
  'url',
  'grade',
  'mark',
  'course',
  'room',
  'schedule',
  'event',
  'dualis',
  'session',
};

const Set<String> _genericValues = <String>{
  'app',
  'debug',
  'profile',
  'release',
  'production',
  'staging',
  'android',
  'ios',
  'web',
  'linux',
  'macos',
  'windows',
  'startup',
  'startup.initialize',
  'main',
  'onboarding',
  'settings',
  'shell',
  'schedule',
  'canteen',
  'dualis',
  'date_management',
  'usefulinformation',
  'useful_information',
  'drawer.tab.schedule',
  'drawer.tab.canteen',
  'drawer.tab.dualis',
  'drawer.tab.date_management',
  'drawer.tab.usefulinformation',
  'drawer.tab.useful_information',
  'schedule.entry',
  'canteen.entry',
  'schedule.refresh',
  'schedule.cache',
  'perf.frame',
  'perf.instant',
  'navigation',
  'analytics.event',
  'analytics.user_property',
};

const Map<String, String> _routeAliases = <String, String>{
  'schedule': 'schedule',
  'canteen': 'canteen',
  'dualis': 'dualis',
  'date_management': 'date_management',
  'usefulInformation': 'useful_information',
  'usefulinformation': 'useful_information',
  'onboarding': 'onboarding',
  'main': 'main',
  'settings': 'settings',
  'shell': 'shell',
};

bool _containsSensitiveTerm(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('technical')) {
    return _sensitiveTerms
        .where((term) => term != 'ical')
        .any(normalized.contains);
  }
  return _sensitiveTerms.any(normalized.contains);
}

bool _isGenericValue(String value) {
  final normalized = value.trim().toLowerCase();
  return _genericValues.contains(normalized);
}

bool isSensitiveDiagnosticsKey(Object? key) {
  if (key == null) return false;
  return _containsSensitiveTerm(key.toString());
}

String sanitizeDiagnosticsName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'unknown';
  final route = sanitizeRouteName(trimmed);
  if (route != 'unknown') return route;
  if (_isGenericValue(trimmed)) return trimmed;
  if (_containsSensitiveTerm(trimmed) || _looksLikeUrl(trimmed)) {
    return sentryRedactedValue;
  }
  return trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
}

String sanitizeRouteName(String? name) {
  if (name == null) return 'unknown';
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'unknown';
  final withoutQuery = _stripUrlQuery(trimmed);
  final alias = _routeAliases[withoutQuery] ?? _routeAliases[trimmed];
  if (alias != null) return alias;
  if (withoutQuery.startsWith('/')) {
    final firstSegment = withoutQuery
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .cast<String?>()
        .firstOrNull;
    final segmentAlias =
        _routeAliases[firstSegment] ??
        _routeAliases[firstSegment?.toLowerCase() ?? ''];
    if (segmentAlias != null) return segmentAlias;
  }
  return 'unknown';
}

RouteSettings? sanitizeSentryRouteSettings(RouteSettings? settings) {
  if (settings == null) return null;
  return RouteSettings(name: sanitizeRouteName(settings.name));
}

Object? sanitizeDiagnosticsValue(Object? value, {Object? key, int depth = 0}) {
  if (value == null || value is num || value is bool) return value;
  if (isSensitiveDiagnosticsKey(key)) return sentryRedactedValue;
  if (depth >= 4) return value is String ? _sanitizeStringValue(value) : null;

  if (value is Uri) {
    return _sanitizeStringValue(value.toString());
  }
  if (value is String) {
    return _sanitizeStringValue(value);
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Iterable) {
    return value
        .map((entry) => sanitizeDiagnosticsValue(entry, depth: depth + 1))
        .toList(growable: false);
  }
  if (value is Map) {
    return sanitizeDiagnosticsMap(value, depth: depth + 1);
  }
  return sentryRedactedValue;
}

Map<String, Object?> sanitizeDiagnosticsMap(
  Map<dynamic, dynamic> source, {
  int depth = 0,
}) {
  final sanitized = <String, Object?>{};
  for (final entry in source.entries) {
    final key = entry.key?.toString() ?? 'unknown';
    sanitized[key] = sanitizeDiagnosticsValue(
      entry.value,
      key: key,
      depth: depth,
    );
  }
  return sanitized;
}

Map<String, String> sanitizeDiagnosticsTags(Map<String, String> source) {
  return source.map(
    (key, value) =>
        MapEntry(key, sanitizeDiagnosticsValue(value, key: key).toString()),
  );
}

Object sanitizeDiagnosticsThrowable(Object exception) {
  if (exception is SanitizedDiagnosticsException) return exception;
  return SanitizedDiagnosticsException(exception);
}

SentryEvent? scrubSentryEvent(SentryEvent event, Hint hint) {
  event.user = null;
  event.transaction = event.transaction == null
      ? null
      : sanitizeDiagnosticsName(event.transaction!);
  event.culprit = event.culprit == null
      ? null
      : sanitizeDiagnosticsValue(event.culprit).toString();
  event.message = _scrubMessage(event.message);
  event.tags = event.tags == null ? null : sanitizeDiagnosticsTags(event.tags!);
  event.extra = event.extra == null
      ? null
      : sanitizeDiagnosticsMap(event.extra!);
  event.breadcrumbs = event.breadcrumbs
      ?.map(scrubSentryBreadcrumb)
      .nonNulls
      .toList();
  event.request = _scrubRequest(event.request);
  event.exceptions = event.exceptions?.map(_scrubException).toList();
  _scrubContexts(event.contexts);
  return event;
}

SentryTransaction? scrubSentryTransaction(
  SentryTransaction transaction,
  Hint hint,
) {
  scrubSentryEvent(transaction, hint);
  transaction.transaction = sanitizeDiagnosticsName(
    transaction.transaction ?? 'unknown',
  );
  for (final span in transaction.spans) {
    span.context.operation = sanitizeDiagnosticsName(span.context.operation);
    final description = span.context.description;
    span.context.description = description == null
        ? null
        : sanitizeDiagnosticsName(description);
    for (final key in span.data.keys.toList(growable: false)) {
      final value = span.data[key];
      span.removeData(key);
      final sanitized = sanitizeDiagnosticsValue(value, key: key);
      if (sanitized != null && sanitized != sentryRedactedValue) {
        span.setData(key, sanitized);
      }
    }
  }
  return transaction;
}

Breadcrumb? scrubSentryBreadcrumb(Breadcrumb? breadcrumb, [Hint? hint]) {
  if (breadcrumb == null) return null;
  return breadcrumb.copyWith(
    message: breadcrumb.message == null
        ? null
        : sanitizeDiagnosticsName(breadcrumb.message!),
    category: breadcrumb.category == null
        ? null
        : sanitizeDiagnosticsName(breadcrumb.category!),
    data: breadcrumb.data == null
        ? null
        : sanitizeDiagnosticsMap(breadcrumb.data!),
  );
}

class SanitizedDiagnosticsException implements Exception {
  final String type;
  final String message;

  SanitizedDiagnosticsException(Object source)
    : type = source.runtimeType.toString(),
      message = sanitizeDiagnosticsValue(source.toString()).toString();

  @override
  String toString() {
    return message == sentryRedactedValue ? type : '$type: $message';
  }
}

String _sanitizeStringValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final withoutQuery = _stripUrlQuery(trimmed);
  if (_looksLikeUrl(trimmed)) return withoutQuery;
  if (_isGenericValue(trimmed)) return trimmed;
  if (_containsSensitiveTerm(trimmed)) return sentryRedactedValue;
  return withoutQuery;
}

bool _looksLikeUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

String _stripUrlQuery(String value) {
  final queryIndex = value.indexOf('?');
  final fragmentIndex = value.indexOf('#');
  final cutIndexes = <int>[
    if (queryIndex >= 0) queryIndex,
    if (fragmentIndex >= 0) fragmentIndex,
  ];
  if (cutIndexes.isEmpty) return value;
  cutIndexes.sort();
  return value.substring(0, cutIndexes.first);
}

SentryMessage? _scrubMessage(SentryMessage? message) {
  if (message == null) return null;
  return SentryMessage(
    sanitizeDiagnosticsValue(message.formatted).toString(),
    template: message.template == null
        ? null
        : sanitizeDiagnosticsValue(message.template).toString(),
    params: message.params
        ?.map((param) => sanitizeDiagnosticsValue(param))
        .toList(growable: false),
  );
}

SentryException _scrubException(SentryException exception) {
  return exception.copyWith(
    value: exception.value == null
        ? null
        : sanitizeDiagnosticsValue(exception.value).toString(),
  );
}

SentryRequest? _scrubRequest(SentryRequest? request) {
  if (request == null) return null;
  return SentryRequest(
    url: request.url == null ? null : _stripUrlQuery(request.url!),
    method: request.method,
    queryString: '',
    headers: sanitizeDiagnosticsTags(request.headers),
    env: sanitizeDiagnosticsTags(request.env),
    fragment: null,
    apiTarget: request.apiTarget == null
        ? null
        : sanitizeDiagnosticsValue(request.apiTarget).toString(),
  );
}

void _scrubContexts(Contexts contexts) {
  for (final key in contexts.keys.toList(growable: false)) {
    if (key == SentryDevice.type ||
        key == SentryOperatingSystem.type ||
        key == SentryRuntime.listType ||
        key == SentryApp.type ||
        key == SentryTraceContext.type) {
      continue;
    }
    final value = contexts[key];
    contexts[key] = sanitizeDiagnosticsValue(value, key: key);
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
