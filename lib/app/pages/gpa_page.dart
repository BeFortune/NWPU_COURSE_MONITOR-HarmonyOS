import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/frosted_panel.dart';

class GpaPage extends StatelessWidget {
  const GpaPage({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final NumberFormat formatter = NumberFormat('0.00');
    final List<GradeEntry> graded =
        appState.grades
            .where((GradeEntry grade) => grade.finalGradePoint != null)
            .toList()
          ..sort(
            (GradeEntry a, GradeEntry b) =>
                a.courseName.compareTo(b.courseName),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '绩点概览',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '当前学期：${appState.currentSemester.name}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              MetricTile(
                label: '当前学分绩',
                value: formatter.format(appState.currentGpa),
              ),
              MetricTile(
                label: '加权均分',
                value: formatter.format(appState.weightedScore),
              ),
              MetricTile(
                label: '已计入学分',
                value: formatter.format(appState.earnedCredits),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '已出分课程',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '成绩录入入口在课程详情里：展开某门课程后可直接填写绩点。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: graded.isEmpty
                ? const Center(child: Text('当前还没有已出分课程。'))
                : ListView.builder(
                    itemCount: graded.length,
                    itemBuilder: (BuildContext context, int index) {
                      final GradeEntry grade = graded[index];
                      final Course? course = _findCourseByGrade(grade);
                      final String code = (course?.code ?? '').trim();
                      final String gpa = (grade.finalGradePoint ?? 0)
                          .toStringAsFixed(2);

                      return FrostedPanel(
                        enabled: appState.settings.frostedCards,
                        child: ListTile(
                          title: Text(grade.courseName),
                          subtitle: Text(
                            '学分 ${grade.credit.toStringAsFixed(1)}  ·  '
                            '绩点 $gpa  ·  课程代码 ${code.isEmpty ? '-' : code}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Course? _findCourseByGrade(GradeEntry grade) {
    if (grade.courseId != null) {
      for (final Course course in appState.courses) {
        if (course.id == grade.courseId) {
          return course;
        }
      }
    }
    for (final Course course in appState.courses) {
      if (course.name.trim() == grade.courseName.trim()) {
        return course;
      }
    }
    return null;
  }
}
