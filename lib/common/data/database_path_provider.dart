import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
// ios_app_group removed - iOS only package not compatible with Dart 3

Future<String> getDatabasePath(String databaseName) async {
  Directory documentsDirectory = await getApplicationDocumentsDirectory();

  var path = join(documentsDirectory.path, databaseName);

  // iOS-specific migration removed for Android-only build
  // The ios_app_group package is not available for Dart 3

  return path;
}
