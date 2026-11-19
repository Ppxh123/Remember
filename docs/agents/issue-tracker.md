# 任务跟踪

任务和规格存放在 `Ppxh123/Remember` 的 GitHub Issues。使用 `gh` 操作，在仓库内由 `git remote -v` 确认目标。

## Issue 操作

- 发布任务或规格时，使用 `gh issue create --title "标题" --body-file <正文文件>`。
- 读取任务时，使用 `gh issue view <编号> --comments`。需要单独读取标签时，使用 `gh issue view <编号> --json labels`。
- 列出任务时，使用 `gh issue list --state open --json number,title,body,labels,comments`，按任务使用 `--label` 或调整 `--state`。
- 发表评论时，使用 `gh issue comment <编号> --body-file <评论文件>`。
- 应用或移除标签时，使用 `gh issue edit <编号> --add-label "标签"` 或 `gh issue edit <编号> --remove-label "标签"`。标签名称见 `triage-labels.md`。
- 关闭任务时，使用 `gh issue close <编号> --comment "关闭原因"`。

## Pull requests as a triage surface

**PRs as a request surface: no.**

设为 `yes` 时，外部 PR 使用相同的分诊标签和状态。通过 `gh pr view <编号> --comments` 和 `gh pr diff <编号>` 查看详情，再用 `gh pr comment`、`gh pr edit` 或 `gh pr close` 执行相应操作。列出开放的外部 PR 时，调用 `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open'`，保留 `author_association` 为 `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR` 或 `NONE` 的条目。Issue 和 PR 共用编号。遇到裸编号时，先尝试 `gh pr view <编号>`，确认它是 Issue 后使用 `gh issue view <编号>`。

## Wayfinding operations

- **路线图**使用一个带 `wayfinder:map` 标签的 Issue，在正文中记录 Notes、Decisions-so-far 和 Fog。
- **子任务**使用 `wayfinder:<type>` 标签，类型为 `research`、`prototype`、`grilling` 或 `task`。通过 GitHub sub-issue 关联到路线图。该功能不可用时，在路线图正文添加任务清单，在子任务顶部写 `Part of #<路线图编号>`。
- **阻塞关系**使用 GitHub Issue 依赖。先用 `gh api 'repos/{owner}/{repo}/issues/<阻塞任务编号>' --jq .id` 获取阻塞任务的数据库 ID，再用 `gh api --method POST 'repos/{owner}/{repo}/issues/<当前任务编号>/dependencies/blocked_by' -F issue_id=<数据库ID>` 建立关联。依赖功能不可用时，在子任务顶部写 `Blocked by: #<编号>, #<编号>`。
- **选择子任务**时，按路线图顺序找第一个开放、无人认领且所有阻塞任务都已关闭的子任务。通过 `sub_issues` 端点或路线图清单获取子任务，通过 `dependencies/blocked_by` 端点或 `Blocked by:` 行检查阻塞项。
- **认领**时，将 `gh issue edit <编号> --add-assignee @me` 作为本次会话首次写操作。
- **解决**时，将答案评论到子任务，关闭子任务，再把结论和链接追加到路线图的 Decisions-so-far。
