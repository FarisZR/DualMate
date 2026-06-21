import 'dart:io';
import 'package:flutter/foundation.dart';

const String _ApplicationVersion = "2.0";
String get ApplicationVersion {
  if (kDebugMode) {
    final commitHash = _getGitCommitHash();
    final buildDate = _getBuildDate();
    return "$_ApplicationVersion-$buildDate-$commitHash";
  }
  return _ApplicationVersion;
}

String _getGitCommitHash() {
  try {
    final result = Process.runSync('git', ['rev-parse', '--short', 'HEAD']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
  } catch (_) {}
  return 'unknown';
}

String _getBuildDate() {
  return DateTime.now().toLocal().toString().split(' ')[0].replaceAll('-', '');
}

const String ApplicationSourceCodeUrl = "https://github.com/FarisZR/DualMate";

const String ApplicationPrivacyPolicyUrl =
    "https://terms.remal.org/dualmate/privacy-policy/";

const int RateInStoreLaunchAfter = 16;
const int WidgetHelpLaunchAfter = 8;
const int DonateLaunchAfter = 35;
