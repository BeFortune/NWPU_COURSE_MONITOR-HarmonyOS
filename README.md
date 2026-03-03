# NWPU Course Monitor

基于 Flutter 的多端课表与成绩管理应用，支持一次开发，多端运行（Android / iOS / Windows / Web）。

## 功能与特性

- 课表管理
  - 日列表、周列表、周视图三种模式
  - 课程详情折叠展示，支持手动增删改
- 教务导入
  - 支持移动端内置浏览器进入教务系统后一键提取课程
  - 兼容 NWPU 场景的课程解析逻辑
- 成绩与 GPA
  - 课程可绑定成绩/绩点
  - 自动计算当前学期 GPA、加权均分、已修学分
- 导入导出
  - 当前学期：`JSON / CSV`
  - 全部学期：`JSON`
  - `JSON` 可包含作息与提醒设置，便于跨设备迁移
- 提醒能力
  - 基于每节课时间进行上课前通知
  - 提醒提前时间可配置
- 桌面小组件（Android）
  - 4x2 组件展示今日课程
  - 按时间状态区分：未上课 / 上课中 / 已下课
  - 今日课程结束或无课时，自动切换为“今日无课 + 明日课程”
- 主题与界面
  - 浅色 / 深色模式
  - 轻量磨砂风格与移动端/桌面端适配
- 学期管理
  - 新建、切换、编辑学期
  - 按学期独立管理课表与成绩

## 平台支持

- Android：完整功能（含课程提醒、小组件）
- iOS：核心功能可用（提醒可用；小组件需额外 WidgetKit 扩展配置）
- Windows：核心功能可用
- Web：核心页面可运行（系统级提醒/小组件能力受平台限制）

## 快速开始
release 版本已上传至 GitHub Releases
如果你想要对项目进行本地编译，则需要满足以下环境要求，并按照步骤进行安装、检查和运行。
### 环境要求

- Flutter 3.41.x
- Dart 3.11.x
- JDK 17

### 安装与检查

```bash
flutter pub get
flutter analyze
flutter test
```

### 运行

```bash
flutter run -d android
flutter run -d windows
```

### 构建 APK

```bash
flutter build apk --release
```

网络环境受限时可使用：

```bash
cmd /c "set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn&& flutter build apk --release"
```

## 项目结构

```text
NWPU_COURSE_MONITOR/
├── android/ ios/ web/ windows/
├── lib/
│   ├── app/        # 页面与 UI
│   ├── models/     # 数据模型
│   ├── services/   # 导入、存储、提醒、组件同步
│   └── state/      # 应用状态管理
├── test/
└── docs/
```

## 许可证

MIT License

