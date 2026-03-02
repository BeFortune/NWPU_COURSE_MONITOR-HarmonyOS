import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';

class WidgetSyncService {
  static const String _qualifiedProviderName =
      'com.nwpu.nwpu_course_monitor.CourseTodayWidgetProvider';

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> sync({
    required List<Course> courses,
    required AppSettings settings,
    required DateTime now,
  }) async {
    if (!_supported) {
      return;
    }

    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));

    final List<Course> todayCourses = _coursesForDate(courses, settings, today);
    final List<Course> tomorrowCourses = _coursesForDate(
      courses,
      settings,
      tomorrow,
    );

    if (todayCourses.isNotEmpty) {
      await HomeWidget.saveWidgetData<String>('widget_mode', 'today');
      await HomeWidget.saveWidgetData<String>(
        'widget_title',
        DateFormat('M月d日 EEEE', 'zh_CN').format(today),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_today',
        _buildCourseLines(todayCourses, maxLines: 4, showOverflowSummary: true),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_footer',
        tomorrowCourses.isEmpty ? '明日暂无课程' : '明日 ${tomorrowCourses.length} 门课',
      );
    } else {
      final List<String> blessings = <String>[
        '今天没课，记得休息和运动。',
        '空闲日也别忘了复盘。',
        '祝你今天高效又轻松。',
        '没有课程，适合推进计划。',
        '把今天当作整理节奏的一天。',
        '去做一件一直想做的小事。',
        '没有课程，也别忘了补水和走动。',
        '今天适合把待办清空一半。',
        '愿你今天心情稳定、学习顺利。',
        '今天没有课，给自己一点奖励。',
        '可以慢一点，但别停下来。',
        '祝你今天事事顺意。',
        '休整也是进步的一部分。',
        '今天适合安排一次高质量自习。',
        '轻松的一天，也能很有收获。',
      ];
      final int idx = Random(
        now.millisecondsSinceEpoch,
      ).nextInt(blessings.length);

      await HomeWidget.saveWidgetData<String>('widget_mode', 'empty');
      await HomeWidget.saveWidgetData<String>(
        'widget_empty_left_title',
        '今日无课',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_empty_left_body',
        blessings[idx],
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_empty_right_title',
        '明日课程',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_empty_right_body',
        tomorrowCourses.isEmpty
            ? '明日也无课'
            : _buildCourseLines(
                tomorrowCourses,
                maxLines: 3,
                showOverflowSummary: true,
              ),
      );
    }

    bool? updated = await HomeWidget.updateWidget(
      qualifiedAndroidName: _qualifiedProviderName,
      androidName: 'CourseTodayWidgetProvider',
    );
    updated ??= await HomeWidget.updateWidget(
      androidName: 'CourseTodayWidgetProvider',
    );
    updated ??= await HomeWidget.updateWidget(
      name: 'CourseTodayWidgetProvider',
    );
    if (updated != true) {
      throw Exception('组件更新失败，请检查桌面组件是否已添加。');
    }
  }

  List<Course> _coursesForDate(
    List<Course> courses,
    AppSettings settings,
    DateTime date,
  ) {
    final List<Course> result = courses
        .where(
          (Course course) => course.sessions.any(
            (CourseSession session) =>
                session.occursOn(date, settings.termStartMonday),
          ),
        )
        .toList();

    result.sort((Course a, Course b) {
      final int sa = a.sessions.first.startPeriod;
      final int sb = b.sessions.first.startPeriod;
      return sa.compareTo(sb);
    });
    return result;
  }

  String _buildCourseLines(
    List<Course> courses, {
    int maxLines = 4,
    bool showOverflowSummary = false,
  }) {
    if (courses.isEmpty) {
      return '';
    }

    final int safeMaxLines = maxLines < 1 ? 1 : maxLines;
    final int total = courses.length;
    final int reservedForSummary = showOverflowSummary && total > safeMaxLines
        ? 1
        : 0;
    final int lineCount = (safeMaxLines - reservedForSummary).clamp(1, total);

    final List<String> lines = <String>[];
    for (int i = 0; i < lineCount; i++) {
      final Course c = courses[i];
      final CourseSession s = c.sessions.first;
      final String shortName = _truncate(c.name, maxChars: 8);
      lines.add('${s.startPeriod}-${s.endPeriod}节  $shortName');
    }

    if (reservedForSummary == 1) {
      lines.add('等${total - lineCount}节课');
    }

    return lines.join('\n');
  }

  String _truncate(String text, {required int maxChars}) {
    final String trimmed = text.trim();
    if (trimmed.length <= maxChars) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxChars)}...';
  }
}
