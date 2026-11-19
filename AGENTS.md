## Agent skills

### Issue tracker

创建或读取任务与规格时，使用 `Ppxh123/Remember` 的 GitHub Issues。见 `docs/agents/issue-tracker.md`。

### Triage labels

分诊 Issue 时，按英文角色查找对应的中文标签。见 `docs/agents/triage-labels.md`。

### Domain docs

探索领域概念或架构决策前，按单上下文布局读取相关文档。见 `docs/agents/domain.md`。

## Issue 交付

Android 首版阶段逐票完成自动化检查、Android 模拟器验收和评审。Android 首版完成后手动运行 iPhone Simulator 工作流，iOS 待验清单见 GitHub Issue #15。

每完成一个 Issue，先向用户汇报改动、验证结果和推送目标，再为该 Issue 创建一个 Git 提交并推送。
