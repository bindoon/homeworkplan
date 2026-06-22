# Phase 4: Local Reminders - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous — all recommended defaults accepted)

<domain>
## Phase Boundary

为有截止日期的作业和重复规则生成的任务调度本地通知。支持默认提醒时间配置、权限请求、完成/删除时取消通知。依赖 Phase 1 任务模型与 Phase 3 重复规则。

</domain>

<decisions>
## Implementation Decisions

### ReminderService
- UNUserNotificationCenter wrapper
- Stable notification IDs: task.id.uuidString (never hashValue)
- 64 pending notification budget manager — reschedule on app launch, don't schedule all at once

### 提醒策略
- 有 dueDate 的任务：截止日当天早上 + 当天下午未完成再提醒（时间来自设置）
- 重复任务：使用 RecurringRule.reminderTime
- 设置页：morningReminderTime, afternoonReminderTime 默认值

### 权限流
- 首次需要调度时 requestAuthorization
- 拒绝时 Settings 显示说明 + 跳转系统设置的 deep link

### 联动
- TaskRepository markComplete/delete → ReminderService.cancel
- RecurringTaskGenerator 生成任务后 → schedule if rule has reminder

### Claude's Discretion
- Exact default times (建议 08:00 早上, 17:00 下午)
- Notification content 文案

</decisions>

<code_context>
## Existing Code Insights

Phase 1-3 deliver task + recurring infrastructure.

### Integration Points
- ReminderService injected via AppDependencies
- Hook into TaskRepository or ViewModel completion handlers

</code_context>

<specifics>
## Specific Ideas

- OpenSpec local-reminders spec
- PITFALLS: 64 notification limit, simulator unreliable — document for human verification

</specifics>

<deferred>
## Deferred Ideas

- Rich notification actions
- Critical alerts

</deferred>
