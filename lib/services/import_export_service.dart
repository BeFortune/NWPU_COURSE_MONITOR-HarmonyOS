import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

class ImportExportService {
  Future<File> exportToJson(ImportBundle bundle) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final File file = File('${dir.path}\\course_monitor_$stamp.json');

    final Map<String, dynamic> payload = <String, dynamic>{
      'allSemesters': bundle.allSemesters,
      'currentSemesterId': bundle.currentSemesterId,
      'semesters': bundle.semesters
          .map((SemesterInfo e) => e.toJson())
          .toList(),
      'courses': bundle.courses.map((Course e) => e.toJson()).toList(),
      'grades': bundle.grades.map((GradeEntry e) => e.toJson()).toList(),
      if (bundle.settings != null) 'settings': bundle.settings!.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file;
  }

  Future<File> exportAllSemestersToJson({
    required List<SemesterInfo> semesters,
    required String currentSemesterId,
    required List<Course> courses,
    required List<GradeEntry> grades,
    AppSettings? settings,
  }) async {
    final ImportBundle bundle = ImportBundle(
      courses: courses,
      grades: grades,
      semesters: semesters,
      currentSemesterId: currentSemesterId,
      allSemesters: true,
      settings: settings,
    );
    return exportToJson(bundle);
  }

  Future<File> exportToCsv(ImportBundle bundle) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final File file = File('${dir.path}\\course_monitor_$stamp.csv');

    final List<List<dynamic>> rows = <List<dynamic>>[
      <String>[
        'type',
        'semesterId',
        'id',
        'name',
        'code',
        'teacher',
        'location',
        'credit',
        'weekday',
        'startPeriod',
        'endPeriod',
        'startWeek',
        'endWeek',
        'weekType',
        'colorValue',
        'courseId',
        'score',
        'gradePoint',
        'counted',
      ],
    ];

    for (final Course course in bundle.courses) {
      for (final CourseSession session in course.sessions) {
        rows.add(<dynamic>[
          'course',
          course.semesterId,
          course.id,
          course.name,
          course.code,
          course.teacher,
          course.location,
          course.credit,
          session.weekday,
          session.startPeriod,
          session.endPeriod,
          session.startWeek,
          session.endWeek,
          session.weekType.jsonValue,
          course.colorValue,
          '',
          '',
          '',
          '',
        ]);
      }
    }

    for (final GradeEntry grade in bundle.grades) {
      rows.add(<dynamic>[
        'grade',
        grade.semesterId,
        grade.id,
        grade.courseName,
        '',
        '',
        '',
        grade.credit,
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        grade.courseId ?? '',
        grade.score ?? '',
        grade.gradePoint ?? '',
        grade.counted,
      ]);
    }

    await file.writeAsString(const CsvEncoder().convert(rows));
    return file;
  }

  Future<ImportBundle> importFromPath(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      throw Exception('文件不存在: $path');
    }

    final String ext = path.split('.').last.toLowerCase();
    final String content = await file.readAsString();

    if (ext == 'json') {
      return _parseJson(content);
    }
    if (ext == 'csv') {
      return _parseCsv(content);
    }
    throw Exception('暂不支持的文件类型: .$ext');
  }

  ImportBundle _parseJson(String content) {
    final dynamic decoded = jsonDecode(content);

    if (decoded is List<dynamic>) {
      final List<Course> courses = decoded
          .whereType<Map<String, dynamic>>()
          .map(Course.fromJson)
          .where((Course c) => c.sessions.isNotEmpty)
          .toList();
      return ImportBundle(courses: courses, grades: const <GradeEntry>[]);
    }

    if (decoded is Map<String, dynamic>) {
      final bool allSemesters = decoded['allSemesters'] == true;
      final String? currentSemesterId =
          (decoded['currentSemesterId'] as String?)?.trim();
      final dynamic rawSettings = decoded['settings'];
      final AppSettings? settings = rawSettings is Map<String, dynamic>
          ? AppSettings.fromJson(rawSettings)
          : null;

      final List<dynamic> rawSemesters =
          (decoded['semesters'] as List<dynamic>?) ?? <dynamic>[];
      final List<SemesterInfo> semesters = rawSemesters
          .whereType<Map<String, dynamic>>()
          .map(SemesterInfo.fromJson)
          .toList();

      final List<dynamic> rawCourses =
          (decoded['courses'] as List<dynamic>?) ?? <dynamic>[];
      final List<dynamic> rawGrades =
          (decoded['grades'] as List<dynamic>?) ?? <dynamic>[];

      final List<Course> courses = rawCourses
          .whereType<Map<String, dynamic>>()
          .map(Course.fromJson)
          .where((Course c) => c.sessions.isNotEmpty)
          .toList();
      final List<GradeEntry> grades = rawGrades
          .whereType<Map<String, dynamic>>()
          .map(GradeEntry.fromJson)
          .toList();

      return ImportBundle(
        courses: courses,
        grades: grades,
        semesters: semesters,
        currentSemesterId: currentSemesterId,
        allSemesters: allSemesters,
        settings: settings,
      );
    }

    throw Exception('JSON 内容格式无法识别');
  }

  ImportBundle _parseCsv(String content) {
    final List<List<dynamic>> rows = const CsvDecoder(
      dynamicTyping: false,
    ).convert(content).where((List<dynamic> row) => row.isNotEmpty).toList();

    if (rows.isEmpty) {
      return const ImportBundle(courses: <Course>[], grades: <GradeEntry>[]);
    }

    final List<String> headers = rows.first.map((dynamic e) => '$e').toList();
    final Map<String, Course> coursesByKey = <String, Course>{};
    final List<GradeEntry> grades = <GradeEntry>[];

    for (final List<dynamic> raw in rows.skip(1)) {
      final Map<String, String> row = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        if (i < raw.length) {
          row[headers[i]] = '${raw[i]}'.trim();
        }
      }

      final String type = (row['type'] ?? '').toLowerCase();
      if (type == 'course') {
        final CourseSession session = CourseSession(
          weekday: _toInt(row['weekday']) ?? 1,
          startPeriod: _toInt(row['startPeriod']) ?? 1,
          endPeriod: _toInt(row['endPeriod']) ?? 2,
          startWeek: _toInt(row['startWeek']) ?? 1,
          endWeek: _toInt(row['endWeek']) ?? 20,
          weekType: WeekTypeCodec.fromJson(row['weekType']),
        );

        final String courseKey = _csvCourseKey(row);
        final Course? existing = coursesByKey[courseKey];
        if (existing == null) {
          coursesByKey[courseKey] = Course(
            id: _optionalString(row['id']),
            semesterId: _safeString(row['semesterId']),
            name: _safeString(row['name'], fallback: '未命名课程'),
            code: _safeString(row['code']),
            teacher: _safeString(row['teacher']),
            location: _safeString(row['location']),
            credit: _toDouble(row['credit']) ?? 0,
            colorValue: _toInt(row['colorValue']) ?? 0xFF4A90E2,
            sessions: <CourseSession>[session],
          );
        } else {
          final bool sessionExists = existing.sessions.any(
            (CourseSession item) =>
                item.weekday == session.weekday &&
                item.startPeriod == session.startPeriod &&
                item.endPeriod == session.endPeriod &&
                item.startWeek == session.startWeek &&
                item.endWeek == session.endWeek &&
                item.weekType == session.weekType,
          );
          if (!sessionExists) {
            coursesByKey[courseKey] = existing.copyWith(
              sessions: <CourseSession>[...existing.sessions, session],
            );
          }
        }
      } else if (type == 'grade') {
        grades.add(
          GradeEntry(
            id: _optionalString(row['id']),
            semesterId: _safeString(row['semesterId']),
            courseId: _optionalString(row['courseId']),
            courseName: _safeString(row['name'], fallback: '未知课程'),
            credit: _toDouble(row['credit']) ?? 0,
            score: _toDouble(row['score']),
            gradePoint: _toDouble(row['gradePoint']),
            counted: (row['counted'] ?? '').toLowerCase() != 'false',
          ),
        );
      }
    }

    return ImportBundle(courses: coursesByKey.values.toList(), grades: grades);
  }

  int? _toInt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return int.tryParse(value.trim());
  }

  double? _toDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim());
  }

  String _safeString(String? value, {String fallback = ''}) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _optionalString(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _csvCourseKey(Map<String, String> row) {
    final String id = _safeString(row['id']);
    if (id.isNotEmpty) {
      return 'id|$id';
    }
    return 'sig|'
        '${_safeString(row['semesterId']).toLowerCase()}|'
        '${_safeString(row['name']).toLowerCase()}|'
        '${_safeString(row['code']).toLowerCase()}|'
        '${_safeString(row['teacher']).toLowerCase()}|'
        '${_safeString(row['location']).toLowerCase()}|'
        '${(_toDouble(row['credit']) ?? 0).toStringAsFixed(2)}|'
        '${_toInt(row['colorValue']) ?? 0xFF4A90E2}';
  }
}
