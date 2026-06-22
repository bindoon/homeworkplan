# Phase 3: Recurring Tasks - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous — all recommended defaults accepted)

<domain>
## Phase Boundary

为固定作业（如每日练字）提供重复规则 CRUD 与自动生成当日 HomeworkTask 实例。App 启动或进入前台时检查活跃规则并幂等生成。不含通知调度（Phase 4）。

</domain>

<decisions>
## Implementation Decisions

### RecurringRule 模型
- 字段：id, subject, content, frequency (daily/weekdays/weekly/custom weekdays), reminderTime (stored but scheduling deferred to Phase 4), isEnabled, lastGeneratedDate, createdAt
- 与 HomeworkTask 关联：generated tasks 带 recurringRuleId + generationKey (ruleId + date string)

### 生成逻辑
- RecurringTaskGenerator service，在 scenePhase .active 和 onAppear 触发
- 幂等：同一 ruleId + calendar day 只生成一条 task
- 暂停规则不再生成；删除规则不删除已生成历史任务

### UI
- 设置 Tab 新增「重复任务」入口
- 列表展示活跃/暂停规则
- 创建/编辑 form：科目、内容、频率 picker、提醒时间 picker（仅存储）

### Claude's Discretion
- 具体 frequency enum 设计
- 是否在今日 Tab 区分「重复生成」任务样式

</decisions>

<code_context>
## Existing Code Insights

Phase 1: TaskRepository, Subject, HomeworkTask, SettingsView
Phase 2 (may be in progress): Import pipeline

### Integration Points
- RecurringTaskGenerator → TaskRepository.create with sourceType=recurring
- scenePhase observer in HomeworkPlanApp

</code_context>

<specifics>
## Specific Ideas

- OpenSpec recurring-tasks spec
- iCloud dedupe: generationKey prevents duplicate across devices

</specifics>

<deferred>
## Deferred Ideas

- Notification scheduling for recurring (Phase 4)

</deferred>
