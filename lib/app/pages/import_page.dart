import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/frosted_panel.dart';
import 'jwxt_import_webview_page.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  bool _replaceExisting = false;
  bool _applySettingsOnImport = true;
  bool _includeSettingsInJsonExport = true;

  bool get _mobileWebImportSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.appState;
    final List<_ImportAction> actions = <_ImportAction>[
      if (_mobileWebImportSupported)
        _ImportAction(
          icon: Icons.download_for_offline_outlined,
          title: '手机端一键导入',
          description: '登录教务后进入课表页，点击提取并写入当前学期。',
          onTap: _startWebViewImport,
        ),
      _ImportAction(
        icon: Icons.file_open_outlined,
        title: '导入当前学期 JSON/CSV',
        description: '导入到当前选中的学期，可选择合并或覆盖。',
        onTap: _pickAndImportCurrentSemesterFile,
      ),
      _ImportAction(
        icon: Icons.file_download_outlined,
        title: '导出当前学期 JSON',
        description: '仅导出当前学期的课程和成绩。',
        onTap: () => _exportCurrentSemester(json: true),
      ),
      _ImportAction(
        icon: Icons.table_rows_outlined,
        title: '导出当前学期 CSV',
        description: '适合在电脑表格软件中查看和编辑。',
        onTap: () => _exportCurrentSemester(json: false),
      ),
      _ImportAction(
        icon: Icons.cloud_upload_outlined,
        title: '导入全部学期 JSON',
        description: '恢复完整学期数据（含学期列表、课程、成绩）。',
        onTap: _pickAndImportAllSemestersFile,
      ),
      _ImportAction(
        icon: Icons.ios_share_outlined,
        title: '一键导出全部学期',
        description: '生成完整备份 JSON，便于跨设备迁移。',
        onTap: _exportAllSemestersJson,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '导入导出',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '当前学期：${state.currentSemester.name}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          FrostedPanel(
            enabled: state.settings.frostedCards,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('导入时覆盖现有数据'),
                subtitle: const Text('关闭时合并去重，开启时直接替换。'),
                value: _replaceExisting,
                onChanged: (bool value) {
                  setState(() => _replaceExisting = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          FrostedPanel(
            enabled: state.settings.frostedCards,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('导入时应用作息设置'),
                    subtitle: const Text('JSON 包含作息与提醒参数时，同步到当前设备。'),
                    value: _applySettingsOnImport,
                    onChanged: (bool value) {
                      setState(() => _applySettingsOnImport = value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('JSON 导出包含作息设置'),
                    subtitle: const Text('CSV 仍仅导出课程与成绩，不包含作息设置。'),
                    value: _includeSettingsInJsonExport,
                    onChanged: (bool value) {
                      setState(() => _includeSettingsInJsonExport = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FrostedPanel(
            enabled: state.settings.frostedCards,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ActionGrid(actions: actions),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportCurrentSemesterFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['json', 'csv'],
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.path == null) {
      return;
    }

    final String path = picked.files.single.path!;
    try {
      await widget.appState.runWithBusy(() async {
        final ({int courses, int grades}) result = await widget.appState
            .importByFile(
              path: path,
              replaceExisting: _replaceExisting,
              applySettings: _applySettingsOnImport,
            );
        _showMessage('当前学期导入完成：${result.courses} 门课程，${result.grades} 条成绩。');
      });
    } catch (error) {
      _showMessage('导入失败：${_friendlyError(error)}');
    }
  }

  Future<void> _pickAndImportAllSemestersFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.path == null) {
      return;
    }

    final String path = picked.files.single.path!;
    try {
      await widget.appState.runWithBusy(() async {
        final ({int courses, int grades, int semesters}) result = await widget
            .appState
            .importAllSemestersByFile(
              path: path,
              replaceExisting: _replaceExisting,
              applySettings: _applySettingsOnImport,
            );
        _showMessage(
          '全学期导入完成：${result.semesters} 个学期，'
          '${result.courses} 门课程，${result.grades} 条成绩。',
        );
      });
    } catch (error) {
      _showMessage('导入失败：${_friendlyError(error)}');
    }
  }

  Future<void> _exportCurrentSemester({required bool json}) async {
    try {
      await widget.appState.runWithBusy(() async {
        final File file = json
            ? await widget.appState.exportJson(
                includeSettings: _includeSettingsInJsonExport,
              )
            : await widget.appState.exportCsv();
        await _shareOrShowPath(file, fallbackPrefix: '导出成功');
      });
    } catch (error) {
      _showMessage('导出失败：${_friendlyError(error)}');
    }
  }

  Future<void> _exportAllSemestersJson() async {
    try {
      await widget.appState.runWithBusy(() async {
        final File file = await widget.appState.exportAllSemestersJson(
          includeSettings: _includeSettingsInJsonExport,
        );
        await _shareOrShowPath(file, fallbackPrefix: '全学期导出成功');
      });
    } catch (error) {
      _showMessage('导出失败：${_friendlyError(error)}');
    }
  }

  Future<void> _shareOrShowPath(
    File file, {
    required String fallbackPrefix,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path)], text: '课程表备份文件'),
      );
    } catch (_) {
      _showMessage('$fallbackPrefix：${file.path}');
    }
  }

  Future<void> _startWebViewImport() async {
    if (!_mobileWebImportSupported) {
      return;
    }

    final Map<String, dynamic>? payload = await Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute<Map<String, dynamic>>(
            builder: (_) => const JwxtImportWebViewPage(),
            fullscreenDialog: true,
          ),
        );
    if (payload == null) {
      return;
    }

    try {
      await widget.appState.runWithBusy(() async {
        final String pageHtml = (payload['pageHtml'] as String? ?? '').trim();
        AutoImportResult result;
        if (pageHtml.isNotEmpty) {
          result = await widget.appState.importFromTimetableHtmlSnapshot(
            html: pageHtml,
            replaceExisting: _replaceExisting,
          );
          if (result.courses.isEmpty) {
            result = await widget.appState.importFromExtractedPayload(
              payload: payload,
              replaceExisting: _replaceExisting,
            );
          }
        } else {
          result = await widget.appState.importFromExtractedPayload(
            payload: payload,
            replaceExisting: _replaceExisting,
          );
        }
        _showMessage(result.messages.join(' '));
      });
    } catch (error) {
      _showMessage('导入失败：${_friendlyError(error)}');
    }
  }

  String _friendlyError(Object error) {
    final String text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _ImportAction {
  const _ImportAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_ImportAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 900
            ? 3
            : width >= 620
            ? 2
            : 1;
        final double itemWidth = (width - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map(
                (_ImportAction action) => SizedBox(
                  width: itemWidth,
                  child: _ActionCard(action: action),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final _ImportAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(action.icon),
          const SizedBox(height: 8),
          Text(
            action.title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              action.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: action.onTap,
              child: const Text('执行'),
            ),
          ),
        ],
      ),
    );
  }
}
