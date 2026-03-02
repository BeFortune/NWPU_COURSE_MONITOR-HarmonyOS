import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/import_export_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/teaching_system_import_service.dart';
import '../services/widget_sync_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required StorageService storageService,
    required ImportExportService importExportService,
    required NotificationService notificationService,
    required WidgetSyncService widgetSyncService,
    required TeachingSystemImportService teachingImportService,
  }) : _storageService = storageService,
       _importExportService = importExportService,
       _notificationService = notificationService,
       _widgetSyncService = widgetSyncService,
       _teachingImportService = teachingImportService;

  final StorageService _storageService;
  final ImportExportService _importExportService;
  final NotificationService _notificationService;
  final WidgetSyncService _widgetSyncService;
  final TeachingSystemImportService _teachingImportService;

  List<Course> _courses = <Course>[];
  List<GradeEntry> _grades = <GradeEntry>[];
  List<SemesterInfo> _semesters = <SemesterInfo>[];
  String _currentSemesterId = '';
  AppSettings _settings = AppSettings.defaults();

  bool _initialized = false;
  int _busyCount = 0;
  String? _statusMessage;

  bool get initialized => _initialized;
  bool get busy => _busyCount > 0;
  String? get statusMessage => _statusMessage;

  AppSettings get settings => _settings;

  List<SemesterInfo> get semesters =>
      List<SemesterInfo>.unmodifiable(_semesters);

  SemesterInfo get currentSemester {
    for (final SemesterInfo semester in _semesters) {
      if (semester.id == _currentSemesterId) {
        return semester;
      }
    }
    return _semesters.first;
  }

  DateTime get currentTermStartMonday => currentSemester.termStartMonday;

  List<Course> get courses => List<Course>.unmodifiable(
    _courses.where((Course c) => c.semesterId == _currentSemesterId).toList(),
  );

  List<GradeEntry> get grades => List<GradeEntry>.unmodifiable(
    _grades
        .where((GradeEntry g) => g.semesterId == _currentSemesterId)
        .toList(),
  );

  List<Course> get allCourses => List<Course>.unmodifiable(_courses);
  List<GradeEntry> get allGrades => List<GradeEntry>.unmodifiable(_grades);

  double get earnedCredits {
    return grades
        .where((GradeEntry grade) => grade.counted)
        .fold<double>(0, (double sum, GradeEntry grade) => sum + grade.credit);
  }

  double get currentGpa {
    double weightedPoints = 0;
    double totalCredits = 0;
    for (final GradeEntry grade in grades.where((GradeEntry g) => g.counted)) {
      final double? gpa = grade.finalGradePoint;
      if (gpa == null || grade.credit <= 0) {
        continue;
      }
      weightedPoints += gpa * grade.credit;
      totalCredits += grade.credit;
    }
    if (totalCredits <= 0) {
      return 0;
    }
    return weightedPoints / totalCredits;
  }

  double get weightedScore {
    double weightedTotal = 0;
    double totalCredits = 0;
    for (final GradeEntry grade in grades.where((GradeEntry g) => g.counted)) {
      final double? score = grade.score;
      if (score == null || grade.credit <= 0) {
        continue;
      }
      weightedTotal += score * grade.credit;
      totalCredits += grade.credit;
    }
    if (totalCredits <= 0) {
      return 0;
    }
    return weightedTotal / totalCredits;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      _settings = await _storageService.loadSettings();
      final ImportBundle bundle = await _storageService.loadCoursesAndGrades();
      final ({List<SemesterInfo> semesters, String? currentSemesterId})
      semesterState = await _storageService.loadSemesterState();

      _semesters = semesterState.semesters;
      _currentSemesterId = semesterState.currentSemesterId ?? '';

      _ensureSemesterState();
      _settings = _settings.copyWith(termStartMonday: currentTermStartMonday);

      _courses = bundle.courses
          .map((Course c) => _normalizeCourseSemester(c))
          .toList();
      _grades = bundle.grades
          .map((GradeEntry g) => _normalizeGradeSemester(g))
          .toList();

      _courses = _dedupeCourses(_courses)..sort(_compareCourses);
      _grades = _dedupeGrades(_grades)..sort(_compareGrades);

      await _notificationService.initialize();
      await _resyncIntegrations();
      await _storageService.saveSettings(_settings);
      await _persistSemesterState();
    } catch (error) {
      _emitStatus('初始化失败: $error');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<T> runWithBusy<T>(Future<T> Function() action) async {
    _busyCount += 1;
    if (_busyCount == 1) {
      notifyListeners();
    }

    try {
      return await action();
    } catch (error) {
      _emitStatus('操作失败: $error');
      rethrow;
    } finally {
      _busyCount -= 1;
      if (_busyCount < 0) {
        _busyCount = 0;
      }
      if (_busyCount == 0) {
        notifyListeners();
      }
    }
  }

  Future<void> createSemester({
    required String name,
    required DateTime termStartMonday,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final SemesterInfo semester = SemesterInfo(
      name: trimmed,
      termStartMonday: mondayOf(termStartMonday),
    );
    _semesters.add(semester);
    _currentSemesterId = semester.id;
    _settings = _settings.copyWith(termStartMonday: semester.termStartMonday);

    await _storageService.saveSettings(_settings);
    await _persistSemesterState();
    await _resyncIntegrations();
    notifyListeners();
    _emitStatus('已创建学期: ${semester.name}');
  }

  Future<void> switchSemester(String semesterId) async {
    if (_currentSemesterId == semesterId) {
      return;
    }
    final bool exists = _semesters.any((SemesterInfo s) => s.id == semesterId);
    if (!exists) {
      return;
    }

    _currentSemesterId = semesterId;
    _settings = _settings.copyWith(termStartMonday: currentTermStartMonday);

    await _storageService.saveSettings(_settings);
    await _persistSemesterState();
    await _resyncIntegrations();
    notifyListeners();
    _emitStatus('已切换到: ${currentSemester.name}');
  }

  Future<void> updateSemester({
    required String semesterId,
    required String name,
    required DateTime termStartMonday,
  }) async {
    final int index = _semesters.indexWhere(
      (SemesterInfo s) => s.id == semesterId,
    );
    if (index < 0) {
      return;
    }
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _semesters[index] = _semesters[index].copyWith(
      name: trimmed,
      termStartMonday: mondayOf(termStartMonday),
    );

    if (_semesters[index].id == _currentSemesterId) {
      _settings = _settings.copyWith(
        termStartMonday: _semesters[index].termStartMonday,
      );
      await _storageService.saveSettings(_settings);
    }

    await _persistSemesterState();
    await _resyncIntegrations();
    notifyListeners();
    _emitStatus('学期已更新');
  }

  List<Course> coursesForDate(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final List<Course> result = courses
        .where(
          (Course course) => course.sessions.any(
            (CourseSession session) =>
                session.occursOn(day, currentTermStartMonday),
          ),
        )
        .toList();

    result.sort((Course a, Course b) {
      final int aPeriod = _firstPeriodForDate(a, day);
      final int bPeriod = _firstPeriodForDate(b, day);
      if (aPeriod != bPeriod) {
        return aPeriod.compareTo(bPeriod);
      }
      return a.name.compareTo(b.name);
    });
    return result;
  }

  GradeEntry? gradeForCourse(Course course) {
    final List<GradeEntry> semGrades = grades;
    for (final GradeEntry grade in semGrades) {
      if (grade.courseId == course.id) {
        return grade;
      }
    }
    for (final GradeEntry grade in semGrades) {
      if (grade.courseName.trim() == course.name.trim()) {
        return grade;
      }
    }
    return null;
  }

  Future<void> upsertCourse(Course course) async {
    final Course target = course.copyWith(semesterId: _currentSemesterId);
    final int index = _courses.indexWhere((Course c) => c.id == target.id);
    if (index >= 0) {
      _courses[index] = target;
    } else {
      _courses.add(target);
    }

    _courses = _dedupeCourses(_courses)..sort(_compareCourses);
    await _persistData();
    _emitStatus(index >= 0 ? '课程已更新' : '课程已新增');
  }

  Future<void> deleteCourse(String courseId) async {
    final int before = _courses.length;
    _courses.removeWhere((Course c) => c.id == courseId);
    _grades.removeWhere((GradeEntry g) => g.courseId == courseId);
    if (_courses.length == before) {
      return;
    }

    await _persistData();
    _emitStatus('课程已删除');
  }

  Future<void> upsertGrade(GradeEntry grade) async {
    final GradeEntry target = grade.copyWith(semesterId: _currentSemesterId);
    final int index = _grades.indexWhere((GradeEntry g) => g.id == target.id);
    if (index >= 0) {
      _grades[index] = target;
    } else {
      _grades.add(target);
    }

    _grades = _dedupeGrades(_grades)..sort(_compareGrades);
    await _persistData();
    _emitStatus(index >= 0 ? '成绩已更新' : '成绩已新增');
  }

  Future<void> deleteGrade(String gradeId) async {
    final int before = _grades.length;
    _grades.removeWhere((GradeEntry g) => g.id == gradeId);
    if (_grades.length == before) {
      return;
    }

    await _persistData();
    _emitStatus('成绩已删除');
  }

  Future<void> setCourseGradePoint({
    required Course course,
    required double? gradePoint,
  }) async {
    final GradeEntry? existing = gradeForCourse(course);
    if (gradePoint == null) {
      if (existing != null) {
        await deleteGrade(existing.id);
      }
      return;
    }

    final GradeEntry entry = GradeEntry(
      id: existing?.id,
      courseId: course.id,
      semesterId: _currentSemesterId,
      courseName: course.name,
      credit: course.credit,
      score: existing?.score,
      gradePoint: gradePoint,
      counted: true,
    );
    await upsertGrade(entry);
  }

  Future<File> exportJson() async {
    final File file = await _importExportService.exportToJson(
      ImportBundle(
        courses: courses,
        grades: grades,
        semesters: <SemesterInfo>[currentSemester],
        currentSemesterId: _currentSemesterId,
        allSemesters: false,
      ),
    );
    _emitStatus('已导出当前学期 JSON: ${file.path}');
    return file;
  }

  Future<File> exportCsv() async {
    final File file = await _importExportService.exportToCsv(
      ImportBundle(courses: courses, grades: grades),
    );
    _emitStatus('已导出当前学期 CSV: ${file.path}');
    return file;
  }

  Future<File> exportAllSemestersJson() async {
    final File file = await _importExportService.exportAllSemestersToJson(
      semesters: _semesters,
      currentSemesterId: _currentSemesterId,
      courses: _courses,
      grades: _grades,
    );
    _emitStatus('已一键导出全部学期: ${file.path}');
    return file;
  }

  Future<({int courses, int grades})> importByFile({
    required String path,
    required bool replaceExisting,
  }) async {
    final ImportBundle bundle = await _importExportService.importFromPath(path);

    if (bundle.allSemesters) {
      throw Exception('该文件为“全部学期”备份，请使用“导入全部学期”功能。');
    }

    final List<Course> semCourses = bundle.courses
        .map((Course c) => c.copyWith(semesterId: _currentSemesterId))
        .toList();
    final List<GradeEntry> semGrades = bundle.grades
        .map((GradeEntry g) => g.copyWith(semesterId: _currentSemesterId))
        .toList();

    final ({int courses, int grades}) applied = await _applyImportedData(
      courses: semCourses,
      grades: semGrades,
      replaceExisting: replaceExisting,
      semesterId: _currentSemesterId,
    );

    _emitStatus('导入完成：${applied.courses} 门课程，${applied.grades} 条成绩');
    return applied;
  }

  Future<({int courses, int grades, int semesters})> importAllSemestersByFile({
    required String path,
    required bool replaceExisting,
  }) async {
    final ImportBundle bundle = await _importExportService.importFromPath(path);
    if (!bundle.allSemesters) {
      throw Exception('该文件不是“全部学期”备份文件。');
    }

    final List<SemesterInfo> incomingSemesters = bundle.semesters;
    if (incomingSemesters.isNotEmpty) {
      if (replaceExisting) {
        _semesters = incomingSemesters;
      } else {
        for (final SemesterInfo sem in incomingSemesters) {
          if (!_semesters.any((SemesterInfo s) => s.id == sem.id)) {
            _semesters.add(sem);
          }
        }
      }
    }

    if (replaceExisting) {
      _courses = bundle.courses;
      _grades = bundle.grades;
    } else {
      _courses = _dedupeCourses(<Course>[..._courses, ...bundle.courses]);
      _grades = _dedupeGrades(<GradeEntry>[..._grades, ...bundle.grades]);
    }

    _ensureSemesterState(fallbackCurrentId: bundle.currentSemesterId);
    _settings = _settings.copyWith(termStartMonday: currentTermStartMonday);
    await _persistData();
    await _storageService.saveSettings(_settings);
    await _persistSemesterState();

    _emitStatus('已导入全部学期数据');
    return (
      courses: bundle.courses.length,
      grades: bundle.grades.length,
      semesters: incomingSemesters.length,
    );
  }

  Future<AutoImportResult> autoImport({
    required TeachingSystemConfig config,
    required bool replaceExisting,
  }) async {
    final AutoImportResult result = await _teachingImportService
        .importFromTeachingSystem(config);

    final List<Course> semCourses = result.courses
        .map((Course c) => c.copyWith(semesterId: _currentSemesterId))
        .toList();
    final List<GradeEntry> semGrades = result.grades
        .map((GradeEntry g) => g.copyWith(semesterId: _currentSemesterId))
        .toList();

    final ({int courses, int grades}) applied = await _applyImportedData(
      courses: semCourses,
      grades: semGrades,
      replaceExisting: replaceExisting,
      semesterId: _currentSemesterId,
    );

    final List<String> messages = <String>[
      ...result.messages,
      '写入当前学期 ${applied.courses} 门课程，${applied.grades} 条成绩。',
    ];

    final AutoImportResult mergedResult = AutoImportResult(
      courses: semCourses,
      grades: semGrades,
      messages: messages,
    );
    _emitStatus(messages.join(' '));
    return mergedResult;
  }

  Future<AutoImportResult> importFromExtractedPayload({
    required Map<String, dynamic> payload,
    required bool replaceExisting,
  }) async {
    final AutoImportResult result = _teachingImportService
        .importFromExtractedPayload(payload);

    final List<Course> semCourses = result.courses
        .map((Course c) => c.copyWith(semesterId: _currentSemesterId))
        .toList();
    final List<GradeEntry> semGrades = result.grades
        .map((GradeEntry g) => g.copyWith(semesterId: _currentSemesterId))
        .toList();

    final ({int courses, int grades}) applied = await _applyImportedData(
      courses: semCourses,
      grades: semGrades,
      replaceExisting: replaceExisting,
      semesterId: _currentSemesterId,
    );

    final List<String> messages = <String>[
      ...result.messages,
      '写入当前学期 ${applied.courses} 门课程，${applied.grades} 条成绩。',
    ];

    final AutoImportResult mergedResult = AutoImportResult(
      courses: semCourses,
      grades: semGrades,
      messages: messages,
    );
    _emitStatus(messages.join(' '));
    return mergedResult;
  }

  Future<AutoImportResult> importFromTimetableHtmlSnapshot({
    required String html,
    required bool replaceExisting,
  }) async {
    final AutoImportResult result = _teachingImportService
        .importFromTimetableHtmlSnapshot(html);

    final List<Course> semCourses = result.courses
        .map((Course c) => c.copyWith(semesterId: _currentSemesterId))
        .toList();

    final ({int courses, int grades}) applied = await _applyImportedData(
      courses: semCourses,
      grades: const <GradeEntry>[],
      replaceExisting: replaceExisting,
      semesterId: _currentSemesterId,
    );

    final List<String> messages = <String>[
      ...result.messages,
      '写入当前学期 ${applied.courses} 门课程。',
    ];

    final AutoImportResult mergedResult = AutoImportResult(
      courses: semCourses,
      grades: const <GradeEntry>[],
      messages: messages,
    );
    _emitStatus(messages.join(' '));
    return mergedResult;
  }

  Future<void> setThemeMode(ThemeModeSetting value) async {
    if (_settings.themeModeSetting == value) {
      return;
    }
    _settings = _settings.copyWith(themeModeSetting: value);
    await _persistSettings(syncWidget: false, syncNotifications: false);
  }

  Future<void> setReminderMinutes(int minutes) async {
    final int normalized = minutes.clamp(0, 120);
    if (_settings.reminderMinutesBefore == normalized) {
      return;
    }
    _settings = _settings.copyWith(reminderMinutesBefore: normalized);
    await _persistSettings(syncWidget: false, syncNotifications: true);
    _emitStatus('提醒已更新：提前 $normalized 分钟');
  }

  Future<void> setTermStartMonday(DateTime date) async {
    final DateTime monday = mondayOf(date);
    if (currentTermStartMonday == monday) {
      return;
    }
    await updateSemester(
      semesterId: _currentSemesterId,
      name: currentSemester.name,
      termStartMonday: monday,
    );
    _emitStatus('学期起始周已更新');
  }

  Future<void> setDailyScheduleConfig({
    required String dayStartTime,
    required String dayEndTime,
    required int periodDurationMinutes,
    required int maxPeriodsPerDay,
  }) async {
    final String normalizedStart = normalizeTimeText(
      dayStartTime,
      fallback: _settings.dayStartTime,
    );
    final String normalizedEnd = normalizeTimeText(
      dayEndTime,
      fallback: _settings.dayEndTime,
    );
    final int duration = periodDurationMinutes.clamp(30, 180);
    int maxPeriods = maxPeriodsPerDay.clamp(1, 24);

    final int? startMinutes = timeTextToMinutes(normalizedStart);
    final int? endMinutes = timeTextToMinutes(normalizedEnd);
    if (startMinutes != null &&
        endMinutes != null &&
        endMinutes > startMinutes) {
      final int byRange = math.max(1, (endMinutes - startMinutes) ~/ duration);
      maxPeriods = math.min(maxPeriods, byRange);
    }
    final List<String> starts = buildPeriodStartTimes(
      dayStartTime: normalizedStart,
      periodDurationMinutes: duration,
      maxPeriodsPerDay: maxPeriods,
    );

    _settings = _settings.copyWith(
      dayStartTime: normalizedStart,
      dayEndTime: normalizedEnd,
      periodDurationMinutes: duration,
      maxPeriodsPerDay: maxPeriods,
      periodStartTimes: starts,
    );
    await _persistSettings(syncWidget: false, syncNotifications: true);
    _emitStatus('作息参数已更新');
  }

  Future<void> setMaxPeriodsPerDay(int maxPeriodsPerDay) async {
    final int maxPeriods = maxPeriodsPerDay.clamp(1, 24);
    if (_settings.maxPeriodsPerDay == maxPeriods) {
      return;
    }
    final List<String> starts = _normalizePeriodStarts(
      source: _settings.periodStartTimes,
      maxPeriods: maxPeriods,
    );
    _settings = _settings.copyWith(
      maxPeriodsPerDay: maxPeriods,
      periodStartTimes: starts,
    );
    await _persistSettings(syncWidget: false, syncNotifications: true);
    _emitStatus('每天最大节次已更新');
  }

  Future<void> setSchedulePeriods({
    required int maxPeriodsPerDay,
    required List<String> periodStartTimes,
  }) async {
    final int maxPeriods = maxPeriodsPerDay.clamp(1, 24);
    final List<String> starts = _normalizePeriodStarts(
      source: periodStartTimes,
      maxPeriods: maxPeriods,
    );
    _settings = _settings.copyWith(
      maxPeriodsPerDay: maxPeriods,
      periodStartTimes: starts,
    );
    await _persistSettings(syncWidget: false, syncNotifications: true);
    _emitStatus('课程节次与时间已更新');
  }

  Future<void> setFrostedCard(bool enabled) async {
    if (_settings.frostedCards == enabled) {
      return;
    }
    _settings = _settings.copyWith(frostedCards: enabled);
    await _persistSettings(syncWidget: false, syncNotifications: false);
  }

  Future<void> setWidgetWeekSummary(bool enabled) async {
    if (_settings.showWeekSummaryInWidget == enabled) {
      return;
    }
    _settings = _settings.copyWith(showWeekSummaryInWidget: enabled);
    await _persistSettings(syncWidget: true, syncNotifications: false);
    _emitStatus('组件显示设置已更新');
  }

  Future<void> syncWidgetNow() async {
    await _syncWidget(ignoreErrors: false);
    _emitStatus('组件已同步');
  }

  Future<void> regenerateNotifications() async {
    await _syncNotifications(ignoreErrors: false);
    _emitStatus('提醒已重建');
  }

  Future<({int courses, int grades})> _applyImportedData({
    required List<Course> courses,
    required List<GradeEntry> grades,
    required bool replaceExisting,
    required String semesterId,
  }) async {
    final List<Course> incomingCourses = _dedupeCourses(courses);
    final List<GradeEntry> incomingGrades = _dedupeGrades(grades);

    final List<Course> otherCourses = _courses
        .where((Course c) => c.semesterId != semesterId)
        .toList();
    final List<GradeEntry> otherGrades = _grades
        .where((GradeEntry g) => g.semesterId != semesterId)
        .toList();

    final List<Course> currentCourses = _courses
        .where((Course c) => c.semesterId == semesterId)
        .toList();
    final List<GradeEntry> currentGrades = _grades
        .where((GradeEntry g) => g.semesterId == semesterId)
        .toList();

    int appliedCourseCount = 0;
    int appliedGradeCount = 0;

    List<Course> mergedCurrentCourses;
    List<GradeEntry> mergedCurrentGrades;

    if (replaceExisting) {
      mergedCurrentCourses = incomingCourses;
      mergedCurrentGrades = incomingGrades;
      appliedCourseCount = mergedCurrentCourses.length;
      appliedGradeCount = mergedCurrentGrades.length;
    } else {
      final ({List<Course> merged, int added}) mergedCourses = _mergeCourses(
        currentCourses,
        incomingCourses,
      );
      final ({List<GradeEntry> merged, int added}) mergedGrades = _mergeGrades(
        currentGrades,
        incomingGrades,
      );
      mergedCurrentCourses = mergedCourses.merged;
      mergedCurrentGrades = mergedGrades.merged;
      appliedCourseCount = mergedCourses.added;
      appliedGradeCount = mergedGrades.added;
    }

    _courses = _dedupeCourses(<Course>[
      ...otherCourses,
      ...mergedCurrentCourses,
    ])..sort(_compareCourses);
    _grades = _dedupeGrades(<GradeEntry>[
      ...otherGrades,
      ...mergedCurrentGrades,
    ])..sort(_compareGrades);

    await _persistData();
    return (courses: appliedCourseCount, grades: appliedGradeCount);
  }

  ({List<Course> merged, int added}) _mergeCourses(
    List<Course> base,
    List<Course> incoming,
  ) {
    final Map<String, Course> map = <String, Course>{};
    for (final Course course in base) {
      map[_courseKey(course)] = course;
    }
    final int before = map.length;
    for (final Course course in incoming) {
      map[_courseKey(course)] = course;
    }
    return (merged: map.values.toList(), added: map.length - before);
  }

  ({List<GradeEntry> merged, int added}) _mergeGrades(
    List<GradeEntry> base,
    List<GradeEntry> incoming,
  ) {
    final Map<String, GradeEntry> map = <String, GradeEntry>{};
    for (final GradeEntry grade in base) {
      map[_gradeKey(grade)] = grade;
    }
    final int before = map.length;
    for (final GradeEntry grade in incoming) {
      map[_gradeKey(grade)] = grade;
    }
    return (merged: map.values.toList(), added: map.length - before);
  }

  List<Course> _dedupeCourses(List<Course> courses) {
    final Map<String, Course> map = <String, Course>{};
    for (final Course course in courses) {
      if (course.sessions.isEmpty) {
        continue;
      }
      map[_courseKey(course)] = course;
    }
    return map.values.toList();
  }

  List<GradeEntry> _dedupeGrades(List<GradeEntry> grades) {
    final Map<String, GradeEntry> map = <String, GradeEntry>{};
    for (final GradeEntry grade in grades) {
      map[_gradeKey(grade)] = grade;
    }
    return map.values.toList();
  }

  String _courseKey(Course course) {
    final List<String> sessionKeys =
        course.sessions
            .map(
              (CourseSession session) =>
                  '${session.weekday}-${session.startPeriod}-${session.endPeriod}-'
                  '${session.startWeek}-${session.endWeek}-${session.weekType.jsonValue}',
            )
            .toList()
          ..sort();

    return '${course.semesterId.trim().toLowerCase()}|'
        '${course.name.trim().toLowerCase()}|'
        '${course.code.trim().toLowerCase()}|'
        '${course.teacher.trim().toLowerCase()}|'
        '${course.location.trim().toLowerCase()}|'
        '${course.credit.toStringAsFixed(2)}|'
        '${sessionKeys.join(';')}';
  }

  String _gradeKey(GradeEntry grade) {
    final String score = grade.score == null
        ? ''
        : grade.score!.toStringAsFixed(2);
    final String gpa = grade.gradePoint == null
        ? ''
        : grade.gradePoint!.toStringAsFixed(2);

    return '${grade.semesterId.trim().toLowerCase()}|'
        '${grade.courseName.trim().toLowerCase()}|'
        '${grade.credit.toStringAsFixed(2)}|'
        '$score|'
        '$gpa|'
        '${grade.counted}';
  }

  int _compareCourses(Course a, Course b) {
    if (a.semesterId != b.semesterId) {
      return a.semesterId.compareTo(b.semesterId);
    }

    final CourseSession aSession = _firstSession(a);
    final CourseSession bSession = _firstSession(b);

    if (aSession.weekday != bSession.weekday) {
      return aSession.weekday.compareTo(bSession.weekday);
    }
    if (aSession.startPeriod != bSession.startPeriod) {
      return aSession.startPeriod.compareTo(bSession.startPeriod);
    }
    if (aSession.endPeriod != bSession.endPeriod) {
      return aSession.endPeriod.compareTo(bSession.endPeriod);
    }
    return a.name.compareTo(b.name);
  }

  int _compareGrades(GradeEntry a, GradeEntry b) {
    if (a.semesterId != b.semesterId) {
      return a.semesterId.compareTo(b.semesterId);
    }
    final int nameCompare = a.courseName.compareTo(b.courseName);
    if (nameCompare != 0) {
      return nameCompare;
    }
    return a.credit.compareTo(b.credit);
  }

  CourseSession _firstSession(Course course) {
    final List<CourseSession> sessions =
        List<CourseSession>.from(course.sessions)
          ..sort((CourseSession a, CourseSession b) {
            if (a.weekday != b.weekday) {
              return a.weekday.compareTo(b.weekday);
            }
            if (a.startPeriod != b.startPeriod) {
              return a.startPeriod.compareTo(b.startPeriod);
            }
            return a.endPeriod.compareTo(b.endPeriod);
          });
    return sessions.first;
  }

  int _firstPeriodForDate(Course course, DateTime date) {
    final List<int> starts = course.sessions
        .where(
          (CourseSession session) =>
              session.occursOn(date, currentTermStartMonday),
        )
        .map((CourseSession session) => session.startPeriod)
        .toList();

    if (starts.isEmpty) {
      return 999;
    }
    return starts.reduce(math.min);
  }

  Course _normalizeCourseSemester(Course course) {
    if (course.semesterId.trim().isNotEmpty) {
      return course;
    }
    return course.copyWith(semesterId: _currentSemesterId);
  }

  GradeEntry _normalizeGradeSemester(GradeEntry grade) {
    if (grade.semesterId.trim().isNotEmpty) {
      return grade;
    }
    return grade.copyWith(semesterId: _currentSemesterId);
  }

  void _ensureSemesterState({String? fallbackCurrentId}) {
    if (_semesters.isEmpty) {
      _semesters = <SemesterInfo>[
        SemesterInfo(
          name: _defaultSemesterName(),
          termStartMonday: _settings.termStartMonday,
        ),
      ];
    }

    final String preferred = (fallbackCurrentId ?? _currentSemesterId).trim();
    if (preferred.isNotEmpty &&
        _semesters.any((SemesterInfo s) => s.id == preferred)) {
      _currentSemesterId = preferred;
      return;
    }

    _currentSemesterId = _semesters.first.id;
  }

  String _defaultSemesterName() {
    final DateTime now = DateTime.now();
    final String term = now.month >= 8 || now.month <= 1 ? '秋季学期' : '春季学期';
    return '${now.year} $term';
  }

  Future<void> _persistData() async {
    await _storageService.saveCourses(_courses);
    await _storageService.saveGrades(_grades);
    notifyListeners();
    await _resyncIntegrations();
  }

  Future<void> _persistSemesterState() async {
    await _storageService.saveSemesterState(
      semesters: _semesters,
      currentSemesterId: _currentSemesterId,
    );
  }

  Future<void> _persistSettings({
    required bool syncWidget,
    required bool syncNotifications,
  }) async {
    await _storageService.saveSettings(_settings);
    notifyListeners();

    if (syncWidget) {
      await _syncWidget(ignoreErrors: true);
    }
    if (syncNotifications) {
      await _syncNotifications(ignoreErrors: true);
    }
  }

  Future<void> _resyncIntegrations() async {
    await _syncWidget(ignoreErrors: true);
    await _syncNotifications(ignoreErrors: true);
  }

  Future<void> _syncWidget({required bool ignoreErrors}) async {
    try {
      final AppSettings runtimeSettings = _settings.copyWith(
        termStartMonday: currentTermStartMonday,
      );
      await _widgetSyncService.sync(
        courses: courses,
        settings: runtimeSettings,
        now: DateTime.now(),
      );
    } catch (_) {
      if (!ignoreErrors) {
        rethrow;
      }
    }
  }

  Future<void> _syncNotifications({required bool ignoreErrors}) async {
    try {
      final AppSettings runtimeSettings = _settings.copyWith(
        termStartMonday: currentTermStartMonday,
      );
      await _notificationService.reschedule(
        courses: courses,
        settings: runtimeSettings,
        now: DateTime.now(),
      );
    } catch (_) {
      if (!ignoreErrors) {
        rethrow;
      }
    }
  }

  void _emitStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  List<String> _normalizePeriodStarts({
    required List<String> source,
    required int maxPeriods,
  }) {
    final List<String> normalized = source
        .map((String item) => normalizeTimeText(item, fallback: ''))
        .where((String item) => item.isNotEmpty)
        .toList();

    final List<String> fallback = _settings.periodStartTimes.isNotEmpty
        ? _settings.periodStartTimes
        : AppSettings.defaults().periodStartTimes;
    for (final String item in fallback) {
      if (normalized.length >= maxPeriods) {
        break;
      }
      normalized.add(normalizeTimeText(item, fallback: '08:00'));
    }

    while (normalized.length < maxPeriods) {
      final String base = normalized.isEmpty ? '08:00' : normalized.last;
      final int? minutes = timeTextToMinutes(base);
      final int next = ((minutes ?? (8 * 60)) + 55) % (24 * 60);
      final int hour = next ~/ 60;
      final int minute = next % 60;
      normalized.add(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }

    return normalized.take(maxPeriods).toList();
  }
}
