---
phase: 01-daily-task-list-data-foundation
plan: 03
subsystem: ios
tags: [date-browsing, swiftdata-fetch]
requires:
  - phase: 01-02
    provides: TaskRepository CRUD
provides:
  - TaskRepository date-scoped fetch methods
  - TodayView date picker
  - AllTasksView grouped by date
affects: []
tech-stack:
  added: []
  patterns: [Calendar.startOfDay predicates, AllTasksViewModel grouping]
key-files:
  created:
    - HomeworkPlan/ViewModels/AllTasksViewModel.swift
  modified:
    - HomeworkPlan/Repositories/TaskRepository.swift
    - HomeworkPlan/Views/Tabs/TodayView.swift
    - HomeworkPlan/Views/Tabs/AllTasksView.swift
    - HomeworkPlanTests/HomeworkPlanTests/TaskRepositoryTests.swift
requirements-completed: [TASK-06]
duration: 15min
completed: 2026-06-22
---

# Phase 1 Plan 03: Date Browsing Summary

**Today tab compact DatePicker with selected-day filtering and All tab date-section grouped task history**

## Accomplishments

- fetchTasks(dueOn:includeCompleted:) and fetchAllTasksGroupedByDate() with unit tests
- TodayView shows 正在查看 banner for non-today dates
- AllTasksView displays complete and incomplete tasks with section titles 今天/昨天/日期

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

---
*Phase: 01-daily-task-list-data-foundation*
*Completed: 2026-06-22*
