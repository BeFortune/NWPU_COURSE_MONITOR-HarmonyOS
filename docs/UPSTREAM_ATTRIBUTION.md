# Upstream Attribution

本文件用于记录本仓库引用/改写的上游项目来源与许可证信息。

## Upstream Repository

- Repository: `Whippap/soaring-schedule`
- URL: `https://github.com/Whippap/soaring-schedule`
- Upstream License: `MIT`
- Checked Date: `2026-03-02`
- License Reference: `https://raw.githubusercontent.com/Whippap/soaring-schedule/main/LICENSE`

## Snapshot Files Stored in This Repo

为方便审计与对照，以下参考快照已保留在本仓库：

- `docs/references/soaring-schedule/README.md`
- `docs/references/soaring-schedule/jwxtParser.ts`
- `docs/references/soaring-schedule/CourseImportWizard.tsx`
- `docs/references/soaring-schedule/JwxtWebView.tsx`
- `docs/references/soaring-schedule/build-flow.md`

## Adapted Implementation in This Repo

以下 Dart 实现参考了上游项目中 JWXT 导入与页面提取思路，并根据 Flutter 技术栈与本项目数据模型进行了改写：

- `lib/services/teaching_system_import_service.dart`
- `lib/app/pages/jwxt_import_webview_page.dart`

## Compliance Notes

1. 本仓库采用 MIT 许可证，和上游 MIT 许可证兼容。
2. 若后续继续引入第三方代码，请同步在本文件追加来源、许可证、映射文件与变更说明。
3. 发布时应保留本仓库 `LICENSE` 与本文件，保证来源可追溯。
