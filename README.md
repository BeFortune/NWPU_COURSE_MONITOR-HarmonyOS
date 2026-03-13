# NWPU Course Monitor - HarmonyOS NEXT 版

**原项目移植版** | 基于 Flutter OHOS 的西北工业大学课程监控助手

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

本仓库是 [原 NWPU_COURSE_MONITOR](https://github.com/fantian-bilibili/NWPU_COURSE_MONITOR) 的 **HarmonyOS NEXT (Flutter OHOS)** 移植版本，专为 NWPU 学生打造，支持在 HarmonyOS 设备上运行课表、成绩、提醒等核心功能。

## ✨ 功能与特性（已适配 HarmonyOS）
- 课表管理（日/周列表、周视图）
- 教务一键导入 + NWPU 专属解析
- 成绩 & GPA 自动计算
- 课程提醒（ArkTS NotificationAbility + MethodChannel）
- HarmonyOS Form 卡片（替代 Android 小组件）
- 浅色/深色模式 + 鸿蒙风格适配
- 多学期独立管理 + JSON 导入导出

## 🔔 HarmonyOS 本地通知

- ArkTS 侧 `MethodChannel` 处理逻辑：`ohos/entry/src/main/ets/ability/NotificationAbility.ets` 新增插件会在 `nwpu/course_monitor/notification` 通道上注册 `showNotification`，自动处理通知权限、振动与系统铃声，并在调用成功后通过 `notificationManager.publish` 发布通知。
- Flutter 侧调用示例（仅在 HarmonyOS NEXT / OpenHarmony API 16 生效）：

```dart
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class OhosNotificationBridge {
  static const MethodChannel _channel = MethodChannel('nwpu/course_monitor/notification');

  static Future<void> showNotification({
    required String title,
    required String body,
    String channelId = 'course-reminder',
  }) async {
    if (!Platform.isOhos) {
      return;
    }
    await _channel.invokeMethod('showNotification', {
      'title': title,
      'body': body,
      'channelId': channelId,
    });
  }
}
```

在 Flutter 任意位置调用 `OhosNotificationBridge.showNotification(...)` 即可触发鸿蒙原生通知，其他平台会被自动忽略。

## 📱 平台支持（更新）
- **HarmonyOS NEXT**：完整功能（推荐使用 DevEco Studio）
- Android：完整功能（原生）
- iOS / Windows / Web：核心功能可用

## 🚀 快速开始（HarmonyOS 专属）

### 环境要求
- DevEco Studio（最新版）
- HarmonyOS SDK（NEXT）
- Flutter 3.41.x + OHOS 插件

### 在 DevEco Studio 中运行
```bash
# 1. Clone 本仓库
git clone https://github.com/BeFortune/NWPU_COURSE_MONITOR-HarmonyOS.git

# 2. 生成 OHOS 项目结构
cd NWPU_COURSE_MONITOR-HarmonyOS
flutter create --platforms ohos .

# 3. 安装依赖（已包含 OHOS override）
flutter pub get

# 4. 运行到 HarmonyOS 设备/模拟器
flutter run -d ohos
