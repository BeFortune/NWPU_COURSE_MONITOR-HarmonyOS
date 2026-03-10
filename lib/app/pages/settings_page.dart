import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/frosted_panel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _maxPeriodsController;
  final List<TextEditingController> _periodControllers =
      <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _maxPeriodsController = TextEditingController();
    _syncControllersFromState();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllersFromState();
  }

  @override
  void dispose() {
    _maxPeriodsController.dispose();
    for (final TextEditingController controller in _periodControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllersFromState() {
    final AppSettings settings = widget.appState.settings;
    _maxPeriodsController.text = settings.maxPeriodsPerDay.toString();
    _rebuildPeriodControllers(
      count: settings.maxPeriodsPerDay,
      values: settings.periodStartTimes,
    );
  }

  void _rebuildPeriodControllers({
    required int count,
    required List<String> values,
  }) {
    for (final TextEditingController controller in _periodControllers) {
      controller.dispose();
    }
    _periodControllers.clear();

    final int maxCount = count.clamp(1, 24);
    for (int i = 0; i < maxCount; i++) {
      final String value = i < values.length ? values[i] : '';
      _periodControllers.add(TextEditingController(text: value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = widget.appState;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '系统设置',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _semesterPanel(context, appState),
          const SizedBox(height: 10),
          _schedulePanel(context, appState),
          const SizedBox(height: 10),
          _themeAndWidgetPanel(context, appState),
        ],
      ),
    );
  }

  Widget _semesterPanel(BuildContext context, AppState appState) {
    return FrostedPanel(
      enabled: appState.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('学期管理', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(appState.currentSemester.id),
              initialValue: appState.currentSemester.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '当前学期',
                isDense: true,
              ),
              items: appState.semesters
                  .map(
                    (SemesterInfo semester) => DropdownMenuItem<String>(
                      value: semester.id,
                      child: Text(
                        semester.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) async {
                if (value == null) {
                  return;
                }
                await appState.runWithBusy(
                  () => appState.switchSemester(value),
                );
              },
            ),
            const SizedBox(height: 10),
            _InfoLine(
              label: '第一周周一',
              value: DateFormat(
                'yyyy-MM-dd',
              ).format(appState.currentSemester.termStartMonday),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _createSemester(context),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('新建学期'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _editSemester(context, appState.currentSemester),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑当前学期'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _schedulePanel(BuildContext context, AppState appState) {
    final AppSettings settings = appState.settings;
    final int maxPeriods =
        int.tryParse(_maxPeriodsController.text.trim()) ??
        settings.maxPeriodsPerDay;
    final int safeMaxPeriods = maxPeriods.clamp(1, 24);

    return FrostedPanel(
      enabled: settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('作息与提醒', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('上课提醒提前 ${settings.reminderMinutesBefore} 分钟'),
            Slider(
              min: 0,
              max: 60,
              divisions: 12,
              value: settings.reminderMinutesBefore.toDouble(),
              onChanged: (double value) async {
                await appState.setReminderMinutes(value.toInt());
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _maxPeriodsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每天理论最大节次',
                hintText: '例如：12',
              ),
              onChanged: (String value) {
                final int parsed = int.tryParse(value.trim()) ?? 0;
                final int target = parsed.clamp(1, 24);
                if (_periodControllers.length == target) {
                  return;
                }
                final List<String> current = _periodControllers
                    .map((TextEditingController c) => c.text.trim())
                    .toList();
                final List<String> next = <String>[];
                for (int i = 0; i < target; i++) {
                  if (i < current.length) {
                    next.add(current[i]);
                  } else if (i < settings.periodStartTimes.length) {
                    next.add(settings.periodStartTimes[i]);
                  } else {
                    next.add('');
                  }
                }
                setState(() {
                  _rebuildPeriodControllers(count: target, values: next);
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              '每节课上课时间（24小时制）',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (
              int i = 0;
              i < safeMaxPeriods && i < _periodControllers.length;
              i++
            ) ...<Widget>[
              Row(
                children: <Widget>[
                  SizedBox(width: 68, child: Text('第${i + 1}节')),
                  Expanded(
                    child: TextField(
                      controller: _periodControllers[i],
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '08:00',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.tonalIcon(
              onPressed: () => _saveMaxPeriods(appState),
              icon: const Icon(Icons.schedule_outlined),
              label: const Text('应用节次与时间'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async =>
                  appState.runWithBusy(appState.regenerateNotifications),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('重建提醒'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeAndWidgetPanel(BuildContext context, AppState appState) {
    return FrostedPanel(
      enabled: appState.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('外观与组件', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ThemeModeSetting>(
              segments: const <ButtonSegment<ThemeModeSetting>>[
                ButtonSegment<ThemeModeSetting>(
                  value: ThemeModeSetting.system,
                  label: Text('跟随系统'),
                ),
                ButtonSegment<ThemeModeSetting>(
                  value: ThemeModeSetting.light,
                  label: Text('浅色'),
                ),
                ButtonSegment<ThemeModeSetting>(
                  value: ThemeModeSetting.dark,
                  label: Text('深色'),
                ),
              ],
              selected: <ThemeModeSetting>{appState.settings.themeModeSetting},
              onSelectionChanged: (Set<ThemeModeSetting> value) async {
                await appState.setThemeMode(value.first);
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用磨砂卡片'),
              subtitle: const Text('课程卡片使用轻量磨砂效果。'),
              value: appState.settings.frostedCards,
              onChanged: (bool value) async => appState.setFrostedCard(value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('组件显示周统计'),
              value: appState.settings.showWeekSummaryInWidget,
              onChanged: (bool value) async =>
                  appState.setWidgetWeekSummary(value),
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
              FilledButton.tonalIcon(
                onPressed: appState.windowsMiniMode
                    ? null
                    : () async => appState.runWithBusy(
                        appState.launchWindowsMiniWindow,
                      ),
                icon: const Icon(Icons.picture_in_picture_alt_outlined),
                label: const Text('切换到小窗模式'),
              ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开机自启动'),
                subtitle: const Text('Windows 登录后自动启动'),
                value: appState.settings.windowsAutoStart,
                onChanged: (bool value) async =>
                    appState.setWindowsAutoStart(value),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async =>
                  appState.runWithBusy(appState.syncWidgetNow),
              icon: const Icon(Icons.widgets_outlined),
              label: const Text('立即同步组件'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSemester(BuildContext context) async {
    final _SemesterDraft? draft = await _showSemesterEditorDialog(
      context,
      title: '新建学期',
      initialName: _suggestSemesterName(),
      initialTermStart: mondayOf(DateTime.now()),
      confirmText: '创建',
    );
    if (draft == null) {
      return;
    }
    await widget.appState.runWithBusy(
      () => widget.appState.createSemester(
        name: draft.name,
        termStartMonday: draft.termStartMonday,
      ),
    );
  }

  Future<void> _editSemester(
    BuildContext context,
    SemesterInfo semester,
  ) async {
    final _SemesterDraft? draft = await _showSemesterEditorDialog(
      context,
      title: '编辑学期',
      initialName: semester.name,
      initialTermStart: semester.termStartMonday,
      confirmText: '保存',
    );
    if (draft == null) {
      return;
    }
    await widget.appState.runWithBusy(
      () => widget.appState.updateSemester(
        semesterId: semester.id,
        name: draft.name,
        termStartMonday: draft.termStartMonday,
      ),
    );
  }

  Future<void> _saveMaxPeriods(AppState appState) async {
    final int maxPeriods =
        int.tryParse(_maxPeriodsController.text.trim()) ?? 12;
    final int safeMaxPeriods = maxPeriods.clamp(1, 24);
    final List<String> periodStarts = <String>[];
    for (int i = 0; i < safeMaxPeriods && i < _periodControllers.length; i++) {
      periodStarts.add(_periodControllers[i].text.trim());
    }

    await appState.runWithBusy(
      () => appState.setSchedulePeriods(
        maxPeriodsPerDay: safeMaxPeriods,
        periodStartTimes: periodStarts,
      ),
    );
    if (!mounted) {
      return;
    }
    _syncControllersFromState();
    setState(() {});
  }

  Future<_SemesterDraft?> _showSemesterEditorDialog(
    BuildContext context, {
    required String title,
    required String initialName,
    required DateTime initialTermStart,
    required String confirmText,
  }) async {
    final TextEditingController nameController = TextEditingController(
      text: initialName,
    );
    DateTime selectedDate = mondayOf(initialTermStart);

    final _SemesterDraft? result = await showDialog<_SemesterDraft>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return AlertDialog(
                  title: Text(title),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '学期名称',
                          hintText: '例如：2026 春季学期',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('第一周周一'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2036),
                            );
                            if (picked == null) {
                              return;
                            }
                            setState(() => selectedDate = mondayOf(picked));
                          },
                          child: const Text('选择'),
                        ),
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final String name = nameController.text.trim();
                        if (name.isEmpty) {
                          return;
                        }
                        Navigator.of(context).pop(
                          _SemesterDraft(
                            name: name,
                            termStartMonday: mondayOf(selectedDate),
                          ),
                        );
                      },
                      child: Text(confirmText),
                    ),
                  ],
                );
              },
        );
      },
    );
    nameController.dispose();
    return result;
  }

  String _suggestSemesterName() {
    final DateTime now = DateTime.now();
    final bool autumn = now.month >= 8 || now.month <= 1;
    return '${now.year} ${autumn ? '秋季学期' : '春季学期'}';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 84, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _SemesterDraft {
  const _SemesterDraft({required this.name, required this.termStartMonday});

  final String name;
  final DateTime termStartMonday;
}
