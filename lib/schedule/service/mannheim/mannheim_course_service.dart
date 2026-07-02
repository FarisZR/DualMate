import 'dart:convert';

import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:http/http.dart';
import 'package:http_client_helper/http_client_helper.dart' as http;

class MannheimCourse {
  final String name;
  final String title;
  final String icalUrl;
  final String scheduleId;

  const MannheimCourse({
    required this.name,
    required this.icalUrl,
    required this.title,
    required this.scheduleId,
  });

  factory MannheimCourse.fromProfileName(String profileName) {
    return MannheimCourse(
      name: profileName,
      icalUrl: MannheimCourseService.icalUrlForProfile(profileName),
      title: "",
      scheduleId: profileName,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MannheimCourse &&
        other.name == name &&
        other.icalUrl == icalUrl &&
        other.title == title &&
        other.scheduleId == scheduleId;
  }

  @override
  int get hashCode => Object.hash(name, icalUrl, title, scheduleId);
}

class MannheimCourseService {
  static final Uri calendarListUri = Uri(
    scheme: "https",
    host: "vorlesungsplan.stuvma.de",
    pathSegments: ["api", "calendars"],
  );

  static Uri profileUriFor(String profileName) {
    return Uri(
      scheme: "https",
      host: "vorlesungsplan.stuvma.de",
      pathSegments: ["profiles", profileName],
    );
  }

  static String icalUrlForProfile(String profileName) {
    return profileUriFor(profileName).toString();
  }

  static bool isMannheimProfileUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    return uri.scheme == "https" &&
        uri.host == "vorlesungsplan.stuvma.de" &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == "profiles" &&
        uri.pathSegments.last.isNotEmpty;
  }

  Future<List<MannheimCourse>> loadCourses([
    CancellationToken? cancellationToken,
  ]) async {
    var coursesResponse = await _makeRequest(
      calendarListUri,
      cancellationToken,
    );
    return parseCourseList(utf8.decode(coursesResponse.bodyBytes));
  }

  List<MannheimCourse> parseCourseList(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! List) {
      throw FormatException("Mannheim course list must be a JSON array");
    }

    final courses = <MannheimCourse>[];

    for (final profileName in decoded) {
      if (profileName is! String) {
        throw FormatException("Mannheim course names must be strings");
      }

      if (profileName.isEmpty) continue;
      courses.add(MannheimCourse.fromProfileName(profileName));
    }

    courses.sort((first, second) => first.name.compareTo(second.name));
    return courses;
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

      var response = await http.HttpClientHelper.get(
        uri,
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
}
