/// Stable class-name normalization used as recurring reminder identity.
///
/// Keep changes to this algorithm backwards-compatible or migrate persisted
/// reminder rules alongside them.
abstract final class CanonicalClassName {
  static final RegExp _onlinePrefix = RegExp(
    r'^\s*\(?online\)?(?:\s*-\s*|\s+)',
    caseSensitive: false,
  );
  static final RegExp _onlineSuffix = RegExp(
    r'(?:\s*-\s*|\s+)\(?online\)?\s*$',
    caseSensitive: false,
  );
  static final RegExp _courseCodePrefix = RegExp(
    r'^[A-Z]{3,}-?[A-Z]+[0-9]*[A-Z]*[0-9]*/?[A-Z]*[0-9]*\s*-?\s*',
  );
  static final RegExp _whitespace = RegExp(r'\s+');

  static String fromTitle(String title) {
    var result = removeCourseCodePrefix(title);
    result = removeOnlineMarker(result);
    return result.trim().replaceAll(_whitespace, ' ');
  }

  static String removeOnlineMarker(String title) {
    return title
        .replaceFirst(_onlinePrefix, '')
        .replaceFirst(_onlineSuffix, '');
  }

  static String removeCourseCodePrefix(String title) {
    final match = _courseCodePrefix.firstMatch(title);
    if (match != null) {
      return title.substring(match.end);
    }

    final trimmed = title.trimLeft();
    final first = trimmed.split(RegExp(r'\s+')).first;
    final isUppercaseCode = first.length >= 3 && first == first.toUpperCase();
    final hasAtLeastTwoDigits = RegExp(r'\d').allMatches(first).length >= 2;
    if (isUppercaseCode && hasAtLeastTwoDigits) {
      return trimmed.substring(first.length).trimLeft();
    }
    return title;
  }

  static String? courseCodePrefix(String title) {
    final match = _courseCodePrefix.firstMatch(title);
    if (match != null) {
      return title.substring(0, match.end).trim();
    }

    final trimmed = title.trimLeft();
    final first = trimmed.split(RegExp(r'\s+')).first;
    if (first.length >= 3 &&
        first == first.toUpperCase() &&
        RegExp(r'\d').allMatches(first).length >= 2) {
      return first;
    }
    return null;
  }
}
