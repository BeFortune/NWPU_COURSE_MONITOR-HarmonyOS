import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class StorageService {
  static const String _coursesKey = 'v1_courses';
  static const String _gradesKey = 'v1_grades';
  static const String _settingsKey = 'v1_settings';
  static const String _semestersKey = 'v2_semesters';
  static const String _currentSemesterKey = 'v2_current_semester';

  Future<ImportBundle> loadCoursesAndGrades() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? courseJson = prefs.getString(_coursesKey);
    final String? gradeJson = prefs.getString(_gradesKey);

    final List<Course> courses = _decodeCourses(courseJson);
    final List<GradeEntry> grades = _decodeGrades(gradeJson);
    return ImportBundle(courses: courses, grades: grades);
  }

  Future<AppSettings> loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? settingJson = prefs.getString(_settingsKey);
    if (settingJson == null || settingJson.trim().isEmpty) {
      return AppSettings.defaults();
    }
    try {
      final dynamic decoded = jsonDecode(settingJson);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } catch (_) {
      return AppSettings.defaults();
    }
    return AppSettings.defaults();
  }

  Future<({List<SemesterInfo> semesters, String? currentSemesterId})>
  loadSemesterState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? semestersJson = prefs.getString(_semestersKey);
    final String? currentSemesterId = prefs.getString(_currentSemesterKey);

    final List<SemesterInfo> semesters = _decodeSemesters(semestersJson);
    return (semesters: semesters, currentSemesterId: currentSemesterId);
  }

  Future<void> saveCourses(List<Course> courses) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String payload = jsonEncode(
      courses.map((Course e) => e.toJson()).toList(),
    );
    await prefs.setString(_coursesKey, payload);
  }

  Future<void> saveGrades(List<GradeEntry> grades) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String payload = jsonEncode(
      grades.map((GradeEntry e) => e.toJson()).toList(),
    );
    await prefs.setString(_gradesKey, payload);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> saveSemesterState({
    required List<SemesterInfo> semesters,
    required String currentSemesterId,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _semestersKey,
      jsonEncode(semesters.map((SemesterInfo e) => e.toJson()).toList()),
    );
    await prefs.setString(_currentSemesterKey, currentSemesterId);
  }

  List<Course> _decodeCourses(String? content) {
    if (content == null || content.trim().isEmpty) {
      return <Course>[];
    }
    try {
      final dynamic decoded = jsonDecode(content);
      if (decoded is List<dynamic>) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(Course.fromJson)
            .where((Course c) => c.sessions.isNotEmpty)
            .toList();
      }
    } catch (_) {
      return <Course>[];
    }
    return <Course>[];
  }

  List<GradeEntry> _decodeGrades(String? content) {
    if (content == null || content.trim().isEmpty) {
      return <GradeEntry>[];
    }
    try {
      final dynamic decoded = jsonDecode(content);
      if (decoded is List<dynamic>) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(GradeEntry.fromJson)
            .toList();
      }
    } catch (_) {
      return <GradeEntry>[];
    }
    return <GradeEntry>[];
  }

  List<SemesterInfo> _decodeSemesters(String? content) {
    if (content == null || content.trim().isEmpty) {
      return <SemesterInfo>[];
    }
    try {
      final dynamic decoded = jsonDecode(content);
      if (decoded is List<dynamic>) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(SemesterInfo.fromJson)
            .toList();
      }
    } catch (_) {
      return <SemesterInfo>[];
    }
    return <SemesterInfo>[];
  }
}
