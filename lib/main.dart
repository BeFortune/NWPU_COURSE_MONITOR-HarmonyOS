import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/course_app.dart';
import 'services/import_export_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/teaching_system_import_service.dart';
import 'services/widget_sync_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');

  final AppState appState = AppState(
    storageService: StorageService(),
    importExportService: ImportExportService(),
    notificationService: NotificationService(),
    widgetSyncService: WidgetSyncService(),
    teachingImportService: TeachingSystemImportService(),
  );
  await appState.initialize();

  runApp(CourseMonitorApp(appState: appState));
}
