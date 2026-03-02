# NWPU Course Monitor

基于 Flutter 的课表与成绩管理应用，目标平台为 Android / iOS / Web / Windows。

## 功能概览

- 课程管理：新增、编辑、删除课程，支持今日/本周视图。
- 导入导出：支持 `JSON / CSV` 导入导出，支持覆盖或合并去重。
- 教务导入（NWPU 适配）：支持 URL + Cookie + Header 抓取课表/成绩。
- 绩点统计：支持手动录入成绩，自动计算学分绩、加权均分、已修学分。
- 提醒与组件：Android 课程提醒 + 桌面小组件同步。
- 主题样式：浅色/深色模式，课程卡片磨砂效果可切换。

## 项目结构

```text
NWPU_COURSE_MONITOR/
├── android/ ios/ web/ windows/   # Flutter 多端工程
├── lib/
│   ├── app/                       # 页面与 UI 组件
│   ├── models/                    # 数据模型
│   ├── services/                  # 存储、导入、通知、组件同步
│   └── state/                     # 应用状态管理
├── test/                          # 测试
├── docs/
│   ├── build/                     # 构建相关说明
│   ├── references/soaring-schedule/ # 参考仓库快照文件
│   └── UPSTREAM_ATTRIBUTION.md    # 第三方来源声明
├── CONTRIBUTING.md
└── README.md
```

## 本地开发

环境：

- Flutter `3.41.2`
- Dart `3.11.0`
- JDK `17`

安装依赖与静态检查：

```bash
flutter pub get
flutter analyze
flutter test
```

Android 运行与构建：

```bash
flutter run -d android
flutter build apk --debug
```

## 测试范围声明（截至 2026-03-02）

- 已完成：Android 端核心功能测试。
- 未完成：Windows 端与 iOS 端系统性测试。
- 当前结论：除 Android 外，其它平台暂不承诺完全一致的稳定性。

## 参考仓库与来源声明（重要）

本项目在“教务解析/导入流程”上参考了以下仓库：

- Upstream: `Whippap/soaring-schedule`
- URL: `https://github.com/Whippap/soaring-schedule`
- Upstream license: `MIT`

为保证来源透明，本仓库保留了参考快照文件：

- `docs/references/soaring-schedule/jwxtParser.ts`
- `docs/references/soaring-schedule/CourseImportWizard.tsx`
- `docs/references/soaring-schedule/JwxtWebView.tsx`
- `docs/references/soaring-schedule/README.md`

改造关系和合规说明见：`docs/UPSTREAM_ATTRIBUTION.md`。

## 许可证

本项目采用 `MIT License`（见仓库根目录 `LICENSE`）。

## AI 协作声明

本仓库当前版本中，大部分代码实现、文档整理与工程规范工作由 `GPT-5.3-CODEX` 协助完成，并由仓库维护者审核后合并发布。
