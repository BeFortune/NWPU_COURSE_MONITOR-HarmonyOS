import 'package:flutter/material.dart';

import '../../models/models.dart';

class GradeEditorDialog extends StatefulWidget {
  const GradeEditorDialog({super.key, this.existing});

  final GradeEntry? existing;

  @override
  State<GradeEditorDialog> createState() => _GradeEditorDialogState();
}

class _GradeEditorDialogState extends State<GradeEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _creditController;
  late TextEditingController _scoreController;
  late TextEditingController _gpaController;
  bool _counted = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existing?.courseName ?? '',
    );
    _creditController = TextEditingController(
      text: '${widget.existing?.credit ?? 0}',
    );
    _scoreController = TextEditingController(
      text: widget.existing?.score == null ? '' : '${widget.existing!.score}',
    );
    _gpaController = TextEditingController(
      text: widget.existing?.gradePoint == null
          ? ''
          : '${widget.existing!.gradePoint}',
    );
    _counted = widget.existing?.counted ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creditController.dispose();
    _scoreController.dispose();
    _gpaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增成绩' : '编辑成绩'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '课程名称 *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _creditController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '学分'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _scoreController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '分数（可选）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _gpaController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '绩点（可选）',
                  hintText: '不填时按分数自动折算',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('计入总绩点'),
                value: _counted,
                onChanged: (bool value) => setState(() => _counted = value),
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
            final GradeEntry grade = GradeEntry(
              id: widget.existing?.id,
              courseName: name,
              credit: double.tryParse(_creditController.text.trim()) ?? 0,
              score: double.tryParse(_scoreController.text.trim()),
              gradePoint: double.tryParse(_gpaController.text.trim()),
              counted: _counted,
            );
            Navigator.of(context).pop(grade);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
