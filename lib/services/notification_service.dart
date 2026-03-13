import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

const bool kIsOHOS = bool.fromEnvironment('dart.library.ohos');

class NotificationService {
  final MethodChannel channel =
      const MethodChannel('com.befortune.nwpu/course_notification');
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Set<int> _ohosReminderIds = <int>{};
  bool _initialized = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  Future<void> initialize() async {
    if (_initialized || !_supported) {
      if (kIsOHOS) {
        _initialized = true;
      }
      return;
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const WindowsInitializationSettings windowsInit =
        WindowsInitializationSettings(
          appName: 'NWPU Course Monitor',
          appUserModelId: 'HClO3.NWPU.CourseMonitor.1',
          guid: '0de31c39-bf09-4d76-8ed3-5fcbf4b26f71',
        );
    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      windows: windowsInit,
    );
    await _plugin.initialize(settings: settings);
    await _requestPermission();
    await _configureTimezone();
    _initialized = true;
  }

  Future<void> _configureTimezone() async {
    tz.initializeTimeZones();
    try {
      final TimezoneInfo timezoneInfo =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> _requestPermission() async {
    if (!_supported) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> reschedule({
    required List<Course> courses,
    required AppSettings settings,
    required DateTime now,
  }) async {
    if (kIsOHOS) {
      await _rescheduleOhos(courses: courses, settings: settings, now: now);
      return;
    }

    if (!_supported) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }

    await _plugin.cancelAll();

    if (settings.reminderMinutesBefore <= 0) {
      return;
    }

    final DateTime dateOnlyNow = DateTime(now.year, now.month, now.day);
    for (int day = 0; day < 21; day++) {
      final DateTime date = dateOnlyNow.add(Duration(days: day));
      final List<Course> dayCourses = courses
          .where(
            (Course course) => course.sessions.any(
              (CourseSession session) =>
                  session.occursOn(date, settings.termStartMonday),
            ),
          )
          .toList();

      for (final Course course in dayCourses) {
        for (final CourseSession session in course.sessions) {
          if (!session.occursOn(date, settings.termStartMonday)) {
            continue;
          }
          final DateTime? classStart = _classStartAt(
            date: date,
            startPeriod: session.startPeriod,
            settings: settings,
          );
          if (classStart == null) {
            continue;
          }
          final DateTime remindAt = classStart.subtract(
            Duration(minutes: settings.reminderMinutesBefore),
          );
          if (!remindAt.isAfter(now)) {
            continue;
          }

          final int notificationId =
              (course.id.hashCode ^ remindAt.millisecondsSinceEpoch) &
              0x7fffffff;
          await showCourseReminder(
            id: notificationId,
            courseName: course.name,
            time: '${classStart.hour.toString().padLeft(2, '0')}:${classStart.minute.toString().padLeft(2, '0')}',
            location: course.location.isEmpty ? '未设置' : course.location,
            minutesBefore: settings.reminderMinutesBefore,
            scheduledAt: remindAt,
          );
        }
      }
    }
  }

  Future<void> _rescheduleOhos({
    required List<Course> courses,
    required AppSettings settings,
    required DateTime now,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    await _cancelAllOhosReminders();

    if (settings.reminderMinutesBefore <= 0) {
      return;
    }

    final DateTime dateOnlyNow = DateTime(now.year, now.month, now.day);
    for (int day = 0; day < 21; day++) {
      final DateTime date = dateOnlyNow.add(Duration(days: day));
      final List<Course> dayCourses = courses
          .where(
            (Course course) => course.sessions.any(
              (CourseSession session) =>
                  session.occursOn(date, settings.termStartMonday),
            ),
          )
          .toList();

      for (final Course course in dayCourses) {
        for (final CourseSession session in course.sessions) {
          if (!session.occursOn(date, settings.termStartMonday)) {
            continue;
          }

          final DateTime? classStart = _classStartAt(
            date: date,
            startPeriod: session.startPeriod,
            settings: settings,
          );
          if (classStart == null) {
            continue;
          }

          final DateTime remindAt = classStart.subtract(
            Duration(minutes: settings.reminderMinutesBefore),
          );
          if (!remindAt.isAfter(now)) {
            continue;
          }

          final int notificationId =
              (course.id.hashCode ^ remindAt.millisecondsSinceEpoch) &
              0x7fffffff;

          final String time =
              '${classStart.hour.toString().padLeft(2, '0')}:${classStart.minute.toString().padLeft(2, '0')}';
          final String location = course.location.isEmpty ? '未设置' : course.location;
          final String title = '即将上课: ${course.name}';
          final String body =
              '${settings.reminderMinutesBefore} 分钟后开始，时间 $time，地点 $location';

          await _scheduleOhosReminder(
            id: notificationId,
            title: title,
            body: body,
            courseName: course.name,
            time: time,
            triggerAt: remindAt,
          );
        }
      }
    }
  }

  Future<void> _scheduleOhosReminder({
    required int id,
    required String title,
    required String body,
    required String courseName,
    required String time,
    required DateTime triggerAt,
  }) async {
    try {
      await channel.invokeMethod('scheduleReminder', <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'courseName': courseName,
        'time': time,
        'triggerAt': triggerAt.millisecondsSinceEpoch,
      });
      _ohosReminderIds.add(id);
    } on PlatformException catch (e) {
      debugPrint(
        '[NotificationService][OHOS] scheduleReminder failed: '
        '${e.code} ${e.message}',
      );
    } catch (e) {
      debugPrint('[NotificationService][OHOS] scheduleReminder exception: $e');
    }
  }

  Future<void> _cancelAllOhosReminders() async {
    try {
      await channel.invokeMethod('cancelAllReminders');
      _ohosReminderIds.clear();
      return;
    } catch (_) {
      // Fallback for old native side without cancelAllReminders.
    }

    for (final int id in List<int>.from(_ohosReminderIds)) {
      try {
        await channel.invokeMethod('cancelReminder', <String, dynamic>{
          'id': id,
        });
      } catch (e) {
        debugPrint('[NotificationService][OHOS] cancelReminder($id) failed: $e');
      }
    }
    _ohosReminderIds.clear();
  }

  Future<void> showCourseReminder({
    required int id,
    required String courseName,
    required String time,
    required String location,
    required int minutesBefore,
    DateTime? scheduledAt,
  }) async {
    final String title = '即将上课: $courseName';
    final String body = '$minutesBefore 分钟后开始，时间 $time，地点 $location';

    if (kIsOHOS) {
      try {
        await channel.invokeMethod('showReminder', <String, dynamic>{
          'title': title,
          'body': body,
          'id': id,
          'courseName': courseName,
          'time': time,
        });
      } on PlatformException catch (e) {
        debugPrint('[NotificationService][OHOS] showReminder failed: ${e.code} ${e.message}');
      } catch (e) {
        debugPrint('[NotificationService][OHOS] showReminder exception: $e');
      }
      return;
    }

    if (!_supported) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }

    if (scheduledAt != null) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'course_reminders',
            '课程提醒',
            channelDescription: '课程开始前提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return;
    }

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'course_reminders',
          '课程提醒',
          channelDescription: '课程开始前提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
  }

  DateTime? _classStartAt({
    required DateTime date,
    required int startPeriod,
    required AppSettings settings,
  }) {
    if (startPeriod <= 0 || startPeriod > settings.periodStartTimes.length) {
      return null;
    }
    final String period = settings.periodStartTimes[startPeriod - 1];
    final List<String> parts = period.split(':');
    if (parts.length != 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
