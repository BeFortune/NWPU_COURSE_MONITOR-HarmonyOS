# Multi-Platform Build & Test Guide

Last updated: 2026-03-03

## 1. Current status in this workspace

- Windows build: passed
  - Command: `flutter build windows --release`
  - Artifact: `build/windows/x64/runner/Release/nwpu_course_monitor.exe`
- Static checks: passed
  - `flutter analyze`
  - `flutter test`

## 2. Windows (current machine)

### Build

```bash
flutter pub get
flutter build windows --release
```

### Smoke test

1. Launch `build/windows/x64/runner/Release/nwpu_course_monitor.exe`
2. Verify:
   - schedule page loading
   - semester switching
   - import/export (CSV/JSON)
   - grade editing and GPA summary

## 3. iOS (must use macOS + Xcode)

Flutter official docs: https://docs.flutter.dev/platform-integration/ios/setup  
Flutter build docs: https://docs.flutter.dev/deployment/ios

### Required environment

- macOS machine
- Xcode + Command Line Tools
- CocoaPods
- Apple Developer signing certificates/profiles

### Build & run

```bash
flutter pub get
flutter devices
flutter run -d <ios_device_id>
```

For archive/release:

```bash
flutter build ipa
```

### iOS full-function notes

- Notification reminders: enabled in app code now.
- Home widget: `home_widget` supports iOS, but you must add a WidgetKit extension in Xcode.
  - Keep Widget `kind` aligned with: `CourseTodayWidget`
  - Current app-side update call already targets this `kind`.

`home_widget` docs: https://docs.page/ABausG/home_widget

## 4. HarmonyOS 6.0 / OpenHarmony

Harmony support in Flutter is not in upstream stable SDK.  
You need the OpenHarmony Flutter toolchain/fork first.

Reference (OpenHarmony-SIG Flutter repo):  
https://gitee.com/openharmony-sig/flutter_flutter  
(repo page currently indicates migration to `gitcode.com/openharmony-sig/flutter_flutter`)

### Required environment (typical)

- OpenHarmony/DevEco toolchain
- `hdc`, `hvigorw`, `ohpm` available in PATH
- Flutter-OpenHarmony SDK/fork installed

### Build flow (toolchain-dependent)

1. Use the OpenHarmony Flutter SDK/fork (not standard `E:/flutter` stable).
2. Re-run dependency install under that toolchain.
3. Build HAP with the forked Flutter command set.
4. Install to device via `hdc` and run smoke tests.

## 5. Feature parity checklist (target)

- Course import (JWXT WebView): Android/iOS
- Local file import/export (CSV/JSON): Android/iOS/Windows
- Reminder notifications: Android/iOS/Windows
- Home widget:
  - Android: supported
  - iOS: requires WidgetKit extension setup
  - Windows: not applicable
  - HarmonyOS: depends on plugin/toolchain support

