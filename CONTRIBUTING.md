# Contributing Guide

## 分支策略

- `main`：稳定发布分支，仅接收 `develop -> main` 的 PR。
- `develop`：日常开发分支，所有开发提交先进入 `develop`。

## 提交信息规范

- 建议使用简洁的 Conventional Commits 风格：
  - `feat: ...`
  - `fix: ...`
  - `docs: ...`
  - `chore: ...`

示例：

```bash
git commit -m "fix(import): improve jwxt location parsing"
```

## 代码注释要求

- 新增或修改复杂逻辑时，必须添加简短、直接的注释，说明“为什么这样实现”。
- 对明显自解释的简单赋值/调用不写冗余注释。
- 注释应随代码变更同步更新，避免过期说明。

## 测试覆盖范围（截至 2026-03-02）

- Android：已完成核心功能验证。
- Windows / iOS：尚未完成系统性验证。

## PR 流程

1. 变更先合入 `develop`。
2. 开发完成后本地通过：
   - `flutter analyze`
   - `flutter test`
3. 发布阶段发起 `develop -> main` PR。
4. PR 描述需包含测试范围与风险点。

## 第三方代码与引用要求

- 引入或改写第三方代码时，必须更新 `docs/UPSTREAM_ATTRIBUTION.md`。
- 必须保留对应许可证要求的版权声明。
- 严禁提交 Cookie、Token、账号密码等敏感信息。
