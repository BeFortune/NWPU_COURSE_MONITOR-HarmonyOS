import 'package:flutter/material.dart';

import '../../models/models.dart';

class CourseEditorDialog extends StatefulWidget {
  const CourseEditorDialog({
    super.key,
    this.existing,
    this.maxPeriodsPerDay = 12,
  });

  final Course? existing;
  final int maxPeriodsPerDay;

  @override
  State<CourseEditorDialog> createState() => _CourseEditorDialogState();
}

class _CourseEditorDialogState extends State<CourseEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _teacherController;
  late TextEditingController _locationController;
  late TextEditingController _creditController;
  late TextEditingController _startWeekController;
  late TextEditingController _endWeekController;

  int _weekday = DateTime.monday;
  int _startPeriod = 1;
  int _endPeriod = 2;
  WeekType _weekType = WeekType.all;
  int _colorValue = 0xFF4A90E2;

  @override
  void initState() {
    super.initState();
    final Course? existing = widget.existing;
    final CourseSession? session = existing?.sessions.isNotEmpty == true
        ? existing!.sessions.first
        : null;

    _nameController = TextEditingController(text: existing?.name ?? '');
    _codeController = TextEditingController(text: existing?.code ?? '');
    _teacherController = TextEditingController(text: existing?.teacher ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
    _creditController = TextEditingController(
      text: existing?.credit.toString() ?? '0',
    );
    _startWeekController = TextEditingController(
      text: '${session?.startWeek ?? 1}',
    );
    _endWeekController = TextEditingController(
      text: '${session?.endWeek ?? 20}',
    );

    _weekday = session?.weekday ?? DateTime.monday;
    final int maxPeriods = widget.maxPeriodsPerDay.clamp(1, 24);
    _startPeriod = (session?.startPeriod ?? 1).clamp(1, maxPeriods);
    _endPeriod = (session?.endPeriod ?? 2).clamp(1, maxPeriods);
    _weekType = session?.weekType ?? WeekType.all;
    _colorValue = existing?.colorValue ?? 0xFF4A90E2;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _creditController.dispose();
    _startWeekController.dispose();
    _endWeekController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int maxPeriods = widget.maxPeriodsPerDay.clamp(1, 24);
    return AlertDialog(
      title: Text(widget.existing == null ? '新增课程' : '编辑课程'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '课程名称 *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: '课程代码（可选）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _teacherController,
                decoration: const InputDecoration(labelText: '任课教师'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: '上课地点'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _creditController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '学分'),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _weekday,
                      decoration: const InputDecoration(labelText: '星期'),
                      items: <DropdownMenuItem<int>>[
                        for (int day = 1; day <= 7; day++)
                          DropdownMenuItem<int>(
                            value: day,
                            child: Text(weekdayLabel(day)),
                          ),
                      ],
                      onChanged: (int? value) {
                        setState(() => _weekday = value ?? DateTime.monday);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<WeekType>(
                      initialValue: _weekType,
                      decoration: const InputDecoration(labelText: '周类型'),
                      items: WeekType.values
                          .map(
                            (WeekType e) => DropdownMenuItem<WeekType>(
                              value: e,
                              child: Text(weekTypeLabel(e)),
                            ),
                          )
                          .toList(),
                      onChanged: (WeekType? value) {
                        setState(() => _weekType = value ?? WeekType.all);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _startPeriod,
                      decoration: const InputDecoration(labelText: '开始节次'),
                      items: <DropdownMenuItem<int>>[
                        for (int i = 1; i <= maxPeriods; i++)
                          DropdownMenuItem<int>(value: i, child: Text('$i')),
                      ],
                      onChanged: (int? value) =>
                          setState(() => _startPeriod = value ?? 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _endPeriod,
                      decoration: const InputDecoration(labelText: '结束节次'),
                      items: <DropdownMenuItem<int>>[
                        for (int i = 1; i <= maxPeriods; i++)
                          DropdownMenuItem<int>(value: i, child: Text('$i')),
                      ],
                      onChanged: (int? value) =>
                          setState(() => _endPeriod = value ?? 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _startWeekController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '起始周'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _endWeekController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '结束周'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _colorValue,
                decoration: const InputDecoration(labelText: '课程颜色'),
                items:
                    const <int>[
                          0xFF4A90E2,
                          0xFF00A38C,
                          0xFF4E6AF3,
                          0xFF2F855A,
                          0xFFD97706,
                          0xFF0E7490,
                        ]
                        .map(
                          (int c) => DropdownMenuItem<int>(
                            value: c,
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Color(c),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '#${c.toRadixString(16).toUpperCase().substring(2)}',
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (int? value) {
                  setState(() => _colorValue = value ?? _colorValue);
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final String name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('课程名称不能为空')));
              return;
            }

            final int startWeek =
                int.tryParse(_startWeekController.text.trim()) ?? 1;
            final int endWeek =
                int.tryParse(_endWeekController.text.trim()) ?? 20;
            final int finalEndPeriod = _endPeriod < _startPeriod
                ? _startPeriod
                : _endPeriod;

            final CourseSession session = CourseSession(
              weekday: _weekday,
              startPeriod: _startPeriod,
              endPeriod: finalEndPeriod,
              startWeek: startWeek <= 0 ? 1 : startWeek,
              endWeek: endWeek < startWeek ? startWeek : endWeek,
              weekType: _weekType,
            );

            final Course result = Course(
              id: widget.existing?.id,
              name: name,
              code: _codeController.text.trim(),
              teacher: _teacherController.text.trim(),
              location: _locationController.text.trim(),
              credit: double.tryParse(_creditController.text.trim()) ?? 0,
              colorValue: _colorValue,
              sessions: <CourseSession>[session],
            );
            Navigator.of(context).pop(result);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
