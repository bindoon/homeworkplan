---
phase: 04-local-reminders
plan: 01
subsystem: ios-notifications
tags: [usernotifications, reminders, swiftui, swiftdata]

requires:
  - phase: 03-recurring-tasks
    provides: RecurringRule.reminderTime, RecurringTaskGenerator, TaskRepository
provides:
  - ReminderService with UNUserNotificationCenter integration
  - NotificationBudgetManager (64 pending limit)
  - ReminderSettings UserDefaults defaults
  - Settings reminder configuration and permission UX
  - TaskRepository / RecurringTaskGenerator reminder hooks
affects: [05-polish]

tech-stack:
  added: []
  patterns:
    - "Stable notification IDs via task.id.uuidString suffixes"
    - "Diff-based pending notification sync (never removeAll)"
    - "14-day horizon reschedule on app foreground"

key-files:
  created:
    - HomeworkPlan/Services/Reminders/ReminderSettings.swift
    - HomeworkPlan/Services/Reminders/ReminderNotificationID.swift
    - HomeworkPlan/Services/Reminders/NotificationBudgetManager.swift
    - HomeworkPlan/Services/Reminders/ReminderNotificationBuilder.swift
    - HomeworkPlan/Services/Reminders/ReminderService.swift
    - HomeworkPlan/Views/Settings/ReminderSettingsView.swift
    - HomeworkPlanTests/HomeworkPlanTests/NotificationBudgetManagerTests.swift
    - HomeworkPlanTests/HomeworkPlanTests/ReminderNotificationBuilderTests.swift
  modified:
    - HomeworkPlan/Repositories/TaskRepository.swift
    - HomeworkPlan/Services/RecurringTaskGenerator.swift
    - HomeworkPlan/App/AppDependencies.swift
    - HomeworkPlan/Views/Tabs/MainTabView.swift
    - HomeworkPlan/Views/Tabs/SettingsView.swift
    - HomeworkPlan/Views/Settings/RecurringRuleFormView.swift

key-decisions:
  - "Due-date tasks: morning + afternoon on due day from ReminderSettings defaults (8:00, 17:00)"
  - "Recurring tasks: single notification at rule.reminderTime on due day"
  - "rescheduleAll diffs pending IDs instead of removeAllPendingNotificationRequests"

patterns-established:
  - "ReminderService injected via AppDependencies; TaskRepository.reminderService optional wire"
  - "Budget manager selects nearest 64 triggers within 14-day horizon"

requirements-completed: [REMND-01, REMND-02, REMND-03, REMND-04, REMND-05]

duration: 45min
completed: 2026-06-22
---

# Phase 4 Plan 01: Local Reminders Summary

**UNUserNotificationCenter reminders with 64-pending budget, settings defaults, and TaskRepository/RecurringTaskGenerator lifecycle hooks.**

## Performance

- **Duration:** ~45 min
- **Completed:** 2026-06-22
- **Tasks:** 3/3
- **Files modified:** 14

## Accomplishments

- ReminderService schedules/cancels local notifications with stable task UUID identifiers
- NotificationBudgetManager enforces iOS 64 pending limit with nearest-date prioritization
- Settings UI for morning/afternoon defaults and permission denial guidance
- TaskRepository and RecurringTaskGenerator integrated for schedule/cancel/reschedule

## Task Commits

1. **Task 1: ReminderSettings, budget manager, builder + tests** — `1ad67d6`
2. **Task 2: ReminderService and repository/generator hooks** — `c057a21`
3. **Task 3: Settings UI** — `97ab24c`

**Planning:** `324007d` (docs: research and plan)

## Self-Check: PASSED

- FOUND: HomeworkPlan/Services/Reminders/ReminderService.swift
- FOUND: HomeworkPlan/Views/Settings/ReminderSettingsView.swift
- FOUND: 1ad67d6, c057a21, 97ab24c
