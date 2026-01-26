import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/module.dart';
import 'package:dualmate/dualis/model/semester.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';

///
/// Decorator class to cache the responses of a dualis service
///
class CacheDualisServiceDecorator extends DualisService {
  final DualisService _service;

  List<Module>? _allModulesCached;
  List<String>? _allSemesterNamesCached;
  Map<String, Semester> _semestersCached = {};
  StudyGrades? _studyGradesCached;

  CacheDualisServiceDecorator(this._service);

  @override
  Future<LoginResult> login(
    String username,
    String password, [
    CancellationToken? cancellationToken,
  ]) {
    return _service.login(username, password, cancellationToken ?? CancellationToken());
  }

  @override
  Future<List<Module>> queryAllModules([
    CancellationToken? cancellationToken,
  ]) async {
    if (_allModulesCached != null) {
      return _allModulesCached!;
    }

    var allModules = await _service.queryAllModules(cancellationToken ?? CancellationToken());

    _allModulesCached = allModules;

    return allModules;
  }

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) async {
    if (_semestersCached.containsKey(name)) {
      return Future.value(_semestersCached[name]);
    }
    var semester = await _service.querySemester(name, cancellationToken ?? CancellationToken());

    _semestersCached[name] = semester;

    return semester;
  }

  @override
  Future<List<String>> querySemesterNames([
    CancellationToken? cancellationToken,
  ]) async {
    if (_allSemesterNamesCached != null) {
      return _allSemesterNamesCached!;
    }

    var allSemesterNames = await _service.querySemesterNames(cancellationToken ?? CancellationToken());

    _allSemesterNamesCached = allSemesterNames;

    return allSemesterNames;
  }

  @override
  Future<StudyGrades> queryStudyGrades([
    CancellationToken? cancellationToken,
  ]) async {
    if (_studyGradesCached != null) {
      return _studyGradesCached!;
    }

    var studyGrades = await _service.queryStudyGrades(cancellationToken ?? CancellationToken());

    _studyGradesCached = studyGrades;

    return studyGrades;
  }

  void clearCache() {
    _allModulesCached = null;
    _allSemesterNamesCached = null;
    _semestersCached = {};
    _studyGradesCached = null;
  }

  @override
  Future<void> logout([
    CancellationToken? cancellationToken,
  ]) async {
    await _service.logout(cancellationToken ?? CancellationToken());    clearCache();
  }
}
