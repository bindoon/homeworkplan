---
phase: 03-recurring-tasks
plan: 01
subsystem: ios-data
tags: [swiftdata, recurring, swiftui, cloudkit]

requires:
  - phase: 01-daily-task-list-data-foundation
    provides: HomeworkTask, TaskRepository, Settings shell, MainTabView
provides:
  - RecurringRule SwiftData model and repository
  - Idempotent RecurringTaskGenerator with generationKey
  - Settings recurring rules CRUD UI
  - App lifecycle hooks for auto-generation
affects: [04-local-reminders]

tech-stack:
  added: []
  patterns:
    - "generationKey idempotency for CloudKit multi-device dedupe"
    - "frequency bitmask for custom weekday selection"

key-files:
  created:
    - HomeworkPlan/Models/RecurringRule.swift
    - HomeworkPlan/Repositories/RecurringRuleRepository.swift
    - HomeworkPlan/Services/RecurringTaskGenerator.swift
    - HomeworkPlan/Views/Settings/RecurringRulesListView.swift
    - HomeworkPlan/Views/Settings/RecurringRuleFormView.swift
    - HomeworkPlanTests/HomeworkPlanTests/RecurringRuleRepositoryTests.swift
    - HomeworkPlanTests/HomeworkPlanTests/RecurringTaskGeneratorTests.swift
  modified:
    - HomeworkPlan/Models/HomeworkTask.swift
    - HomeworkPlan/Models/ImportSourceType.swift
    - HomeworkPlan/Repositories/TaskRepository.swift
    - HomeworkPlan/App/AppDependencies.swift
    - HomeworkPlan/App/HomeworkPlanApp.swift
    - HomeworkPlan/Views/Tabs/MainTabView.swift
    - HomeworkPlan/Views/Tabs/SettingsView.swift

key-decisions:
  - "ImportSourceType.recurring for generated tasks instead of raw string"
  - "customWeekdaysMask bitmask for custom frequency selection"
  - "generationKey format ruleId-yyyy-MM-dd for cross-device idempotency"

patterns-established:
  - "RecurringTaskGenerator checks fetchByGenerationKey before insert"
  - "Delete rule does not cascade to generated HomeworkTask history"

requirements-completed: [RECUR-01, RECUR-02, RECUR-03, RECUR-04]

duration: 25min
completed: 2026-06-22
---

# Phase 3 Plan 01: Recurring Tasks Summary

**幂等 generationKey 驱动的重复规则 CRUD 与 App 生命周期自动生成**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-22T06:10:00Z
- **Completed:** 2026-06-22T06:35:00Z
- **Tasks:** 3/3
- **Files modified:** 14

## Accomplishments

- `RecurringRule` @Model with daily/weekdays/weekly/custom frequency
- `RecurringRuleRepository` CRUD + pause/resume via `isEnabled`
- `RecurringTaskGenerator` idempotent generation on app active
- Settings「重复任务」列表与创建/编辑表单
- Unit tests for repository and generator behavior

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written. Phase 2 had pre-committed schema wiring (`RecurringRule.self` in Schema, `HomeworkTask` fields); this plan completed the missing model/service/UI files.

## Known Stubs

| File | Line | Reason |
|------|------|--------|
| RecurringRuleFormView.swift | reminder section caption | Notification scheduling deferred to Phase 4 |

## Threat Flags

None beyond plan threat model (T-03-01 content trim, T-03-02 generationKey idempotency — both mitigated).

## Self-Check: PASSED

- FOUND: HomeworkPlan/Models/RecurringRule.swift
- FOUND: HomeworkPlan/Services/RecurringTaskGenerator.swift
- FOUND: HomeworkPlan/Views/Settings/RecurringRulesListView.swift
- FOUND: HomeworkPlanTests/HomeworkPlanTests/RecurringTaskGeneratorTests.swift
